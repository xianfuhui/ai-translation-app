import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import '../../core/theme.dart';
import '../../models/language.dart';
import '../../models/history.dart';
import '../../models/model_config.dart';
import '../../services/language_service.dart';
import '../../services/history_service.dart';
import '../../services/vocabulary_service.dart';
import '../../services/translation_service.dart';
import '../../services/model_service.dart';
import '../../services/vosk_service.dart';

/// Màn hình Dịch ngôn ngữ.
///
/// LƯU Ý VỀ OFFLINE:
/// - Danh sách ngôn ngữ tải 1 lần từ backend rồi cache lại để dùng offline.
/// - Speech-to-Text dùng gói `vosk_flutter` (chính chủ alphacep, bản 0.3.48) —
///   ghi âm mic thật, tự tải model theo cấu hình Admin qua `ModelService`,
///   nhận diện offline hoàn toàn (xem `VoskService`).
/// - Text-to-Speech dùng `flutter_tts` (dùng engine TTS hệ thống, tương đương
///   mục tiêu của ML Kit trên Android).
/// - DỊCH văn bản dùng Google ML Kit Translation (`google_mlkit_translation`),
///   chạy hoàn toàn offline sau khi model ngôn ngữ được tải về máy lần đầu.
///   Mã ngôn ngữ dùng để dịch lấy từ kho Model (`type: "mlkit"`) do Admin cấu
///   hình trong Web Admin → Model (Vosk/ML Kit); nếu Admin chưa cấu hình,
///   dùng tạm mã ngôn ngữ (`Language.code`) làm mặc định.
///
/// CHẾ ĐỘ DỊCH TRỰC TIẾP:
/// Nút "Dịch" hoạt động như 1 công tắc Bắt đầu/Dừng:
/// - Bấm lần 1 (Bắt đầu): xin quyền mic, tải/nạp model Vosk theo ngôn ngữ
///   nguồn (cấu hình ở Web Admin → Ngôn ngữ & Model), rồi mở mic nghe liên
///   tục — mỗi khi nhận diện xong 1 câu, tự động dịch ngay bằng ML Kit.
/// - Bấm lần 2 (Dừng): tắt mic, dừng vòng lặp nhận diện + dịch (model Vosk
///   vẫn giữ trong bộ nhớ nên lần Bắt đầu sau không cần tải lại).
class TranslateScreen extends StatefulWidget {
  const TranslateScreen({super.key});

  @override
  State<TranslateScreen> createState() => _TranslateScreenState();
}

class _TranslateScreenState extends State<TranslateScreen> {
  final _languageService = LanguageService();
  final _historyService = HistoryService();
  final _vocabularyService = VocabularyService();
  final _modelService = ModelService();
  final _translationService = TranslationService();
  final _voskService = VoskService();
  final _tts = FlutterTts();
  final _inputController = TextEditingController();

  List<LanguageModel> _languages = [];
  LanguageModel? _sourceLang;
  LanguageModel? _targetLang;
  String _translatedText = '';
  bool _loadingLanguages = true;
  bool _isTranslating = false;
  String?
      _downloadingModelLabel; // hiện khi đang tải model ML Kit / Vosk lần đầu

  // Trạng thái chế độ dịch trực tiếp (start/stop)
  bool _isLiveTranslating = false;
  // Gom tất cả các lượt nói trong 1 phiên Bắt đầu -> Dừng để khi Dừng chỉ lưu
  // MỘT mục lịch sử duy nhất (thay vì mỗi câu 1 mục).
  final List<HistorySegment> _sessionSegments = [];
  DateTime? _sessionStartedAt;

  // Chỉ số các từ đang được CHỌN để ghép thành 1 cụm từ (vd: "đàn" + "bà" ->
  // "đàn bà") trước khi lưu vào từ vựng - tránh lỗi chỉ lưu được đúng 1 âm tiết
  // với các từ ghép. Theo dõi riêng cho câu gốc và câu dịch vì là 2 danh sách
  // từ độc lập.
  final Set<int> _selectedSourceWordIdx = {};
  final Set<int> _selectedTargetWordIdx = {};

  @override
  void dispose() {
    _inputController.dispose();
    _tts.stop();
    _translationService.dispose();
    _voskService.dispose();
    if (_sessionSegments.isNotEmpty &&
        _sourceLang != null &&
        _targetLang != null) {
      _ignoreHistoryFailure(
        _historyService.createConversationHistory(
          sourceLanguage: _sourceLang!.code,
          targetLanguage: _targetLang!.code,
          segments: List<HistorySegment>.from(_sessionSegments),
          startedAt: _sessionStartedAt ?? _sessionSegments.first.at,
          endedAt: DateTime.now(),
        ),
      );
    }
    super.dispose();
  }

  Future<void> _loadLanguages() async {
    try {
      final langs = await _languageService.getLanguages();
      setState(() {
        _languages = langs;
        if (langs.isNotEmpty) {
          _sourceLang = langs.first;
          _targetLang = langs.length > 1 ? langs[1] : langs.first;
        }
        _loadingLanguages = false;
      });
    } catch (e) {
      setState(() => _loadingLanguages = false);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Không tải được danh sách ngôn ngữ: $e')),
      );
    }
  }

  @override
  void initState() {
    super.initState();
    _loadLanguages();
  }

  void _swapLanguages() {
    if (_isLiveTranslating) {
      return; // không đổi ngôn ngữ khi đang dịch trực tiếp
    }
    setState(() {
      final tmp = _sourceLang;
      _sourceLang = _targetLang;
      _targetLang = tmp;
    });
  }

  /// Lấy mã ngôn ngữ dùng để dịch bằng ML Kit: ưu tiên `identifier` của model
  /// loại "mlkit" mà Admin đã cấu hình cho ngôn ngữ này; nếu chưa cấu hình,
  /// dùng tạm mã ngôn ngữ (`Language.code`) làm mặc định.
  Future<String> _resolveMlkitCode(String languageCode) async {
    try {
      final model = await _modelService.getActiveMlkitModel(languageCode);
      if (model != null) return model.identifier;
    } catch (_) {
      // Không lấy được cấu hình từ backend (vd mất mạng) - dùng mặc định bên dưới
    }
    return languageCode;
  }

  /// Đảm bảo model dịch của 1 ngôn ngữ đã có sẵn trên máy, tự tải nếu chưa có
  /// (chỉ tải 1 lần, các lần dịch sau dùng lại model đã tải).
  Future<void> _ensureModelDownloaded(
    String mlkitCode,
    String displayName,
  ) async {
    if (!_translationService.isSupported(mlkitCode)) {
      throw Exception(
        'ML Kit chưa hỗ trợ ngôn ngữ "$mlkitCode" (cấu hình lại ở Web Admin → Model)',
      );
    }
    final downloaded = await _translationService.isModelDownloaded(mlkitCode);
    if (downloaded) return;

    if (mounted) setState(() => _downloadingModelLabel = displayName);
    try {
      await _translationService.downloadModel(mlkitCode);
    } finally {
      if (mounted) setState(() => _downloadingModelLabel = null);
    }
  }

  /// Dịch offline bằng ML Kit giữa 2 mã ngôn ngữ bất kỳ (không nhất thiết phải
  /// đúng chiều nguồn -> đích hiện tại), tự tải model nếu máy chưa có.
  /// Dùng để: dịch cả câu (chiều nguồn -> đích) VÀ gợi ý nghĩa 1 từ đơn lẻ
  /// theo chiều ngược lại khi người dùng chạm vào từ trong câu đã dịch.
  String _langNameForCode(String code) {
    try {
      return _languages.firstWhere((l) => l.code == code).name;
    } catch (_) {
      return code;
    }
  }

  Future<String> _translateBetween(
    String text,
    String fromCode,
    String toCode,
  ) async {
    final resolvedFrom = await _resolveMlkitCode(fromCode);
    final resolvedTo = await _resolveMlkitCode(toCode);

    await _ensureModelDownloaded(resolvedFrom, _langNameForCode(fromCode));
    await _ensureModelDownloaded(resolvedTo, _langNameForCode(toCode));

    return _translationService.translate(
      text: text,
      sourceCode: resolvedFrom,
      targetCode: resolvedTo,
    );
  }

  /// Dịch văn bản offline bằng ML Kit, tự tải model ngôn ngữ nếu máy chưa có.
  Future<String> _translate(String text) async {
    if (_sourceLang == null || _targetLang == null) return text;
    return _translateBetween(text, _sourceLang!.code, _targetLang!.code);
  }

  /// Dịch 1 lần đoạn text hiện có trong ô nhập (dùng khi gõ tay, không ở chế độ trực tiếp)
  Future<void> _handleTranslateOnce() async {
    final text = _inputController.text.trim();
    if (text.isEmpty || _sourceLang == null || _targetLang == null) return;

    setState(() => _isTranslating = true);
    try {
      final result = await _translate(text);
      if (!mounted) return;
      setState(() {
        _translatedText = result;
        _clearWordSelections();
      });
      _saveToHistory(text, result);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Dịch thất bại: $e')));
    } finally {
      if (mounted) setState(() => _isTranslating = false);
    }
  }

  void _saveToHistory(
    String sourceText,
    String translatedText, {
    String type = 'text',
  }) {
    if (_sourceLang == null || _targetLang == null) return;
    // Lưu lịch sử (Online - best effort, không chặn UI nếu lỗi mạng)
    _ignoreHistoryFailure(
      _historyService.createHistory(
        sourceLanguage: _sourceLang!.code,
        targetLanguage: _targetLang!.code,
        sourceText: sourceText,
        translatedText: translatedText,
        type: type,
      ),
    );
  }

  Future<void> _ignoreHistoryFailure(
    Future<TranslationHistoryItem> request,
  ) async {
    try {
      await request;
    } catch (_) {
      // Lịch sử là best effort và không được chặn luồng dịch chính.
    }
  }

  Future<void> _speak(String text, String? langCode) async {
    if (text.isEmpty) return;
    if (langCode != null) await _tts.setLanguage(langCode);
    await _tts.speak(text);
  }

  void _toggleWordSelection(int index, {required bool isSourceText}) {
    setState(() {
      final set =
          isSourceText ? _selectedSourceWordIdx : _selectedTargetWordIdx;
      if (set.contains(index)) {
        set.remove(index);
      } else {
        set.add(index);
      }
    });
  }

  void _clearWordSelections() {
    _selectedSourceWordIdx.clear();
    _selectedTargetWordIdx.clear();
  }

  /// Ghép các từ đang được chọn (theo đúng thứ tự xuất hiện trong câu) thành
  /// 1 cụm từ, vd chọn "đàn" rồi "bà" -> "đàn bà".
  String _buildSelectedPhrase(List<String> words, Set<int> selectedIdx) {
    final sortedIdx = selectedIdx.toList()..sort();
    return sortedIdx.map((i) => words[i]).join(' ');
  }

  Future<void> _saveSelectedPhrase(
    List<String> words, {
    required bool isFromSourceText,
  }) async {
    final selectedIdx =
        isFromSourceText ? _selectedSourceWordIdx : _selectedTargetWordIdx;
    final phrase = _buildSelectedPhrase(words, selectedIdx);
    if (phrase.trim().isEmpty) return;
    await _saveWordAsVocabulary(phrase, isFromSourceText: isFromSourceText);
    if (!mounted) return;
    setState(() => selectedIdx.clear());
  }

  /// gốc (ngôn ngữ nói) HOẶC trong câu đã dịch (ngôn ngữ dịch).
  /// [isFromSourceText] = true nếu từ được chạm nằm trong câu gốc (ngôn ngữ nói);
  /// = false nếu nằm trong câu đã dịch (ngôn ngữ dịch).
  /// Nghĩa của từ được TỰ ĐỘNG dịch sẵn (ML Kit, offline, theo chiều ngược lại
  /// so với ngôn ngữ của từ) để điền vào ô nhập, người dùng vẫn có thể sửa lại
  /// trước khi lưu.
  Future<void> _saveWordAsVocabulary(
    String word, {
    required bool isFromSourceText,
  }) async {
    if (word.trim().isEmpty || _sourceLang == null || _targetLang == null) {
      return;
    }

    final wordLang = isFromSourceText ? _sourceLang! : _targetLang!;
    final meaningLang = isFromSourceText ? _targetLang! : _sourceLang!;

    final formKey = GlobalKey<FormState>();
    final meaningController = TextEditingController();
    bool suggestionStarted = false;
    bool suggesting = true;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setDialogState) {
          // Chỉ gọi dịch gợi ý nghĩa đúng 1 lần khi dialog vừa mở
          if (!suggestionStarted) {
            suggestionStarted = true;
            _translateBetween(word, wordLang.code, meaningLang.code)
                .then((suggested) {
              meaningController.text = suggested;
              if (context.mounted) setDialogState(() => suggesting = false);
            }).catchError((_) {
              if (context.mounted) setDialogState(() => suggesting = false);
            });
          }

          return AlertDialog(
            title: Text('Lưu từ "$word"'),
            content: Form(
              key: formKey,
              child: TextFormField(
                controller: meaningController,
                autofocus: true,
                decoration: InputDecoration(
                  labelText: 'Nghĩa của từ *',
                  helperText: suggesting
                      ? 'Đang gợi ý nghĩa...'
                      : 'Đã tự điền gợi ý, bạn có thể sửa lại',
                  suffixIcon: suggesting
                      ? const Padding(
                          padding: EdgeInsets.all(14),
                          child: SizedBox(
                            height: 14,
                            width: 14,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        )
                      : null,
                ),
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? 'Vui lòng nhập nghĩa của từ'
                    : null,
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Hủy'),
              ),
              FilledButton(
                onPressed: () {
                  if (formKey.currentState!.validate()) {
                    Navigator.pop(context, true);
                  }
                },
                child: const Text('Lưu'),
              ),
            ],
          );
        },
      ),
    );
    if (confirmed != true) return;

    try {
      await _vocabularyService.saveVocabulary(
        word: word,
        meaning: meaningController.text.trim(),
        sourceLanguage: wordLang.code,
        targetLanguage: meaningLang.code,
        source: 'conversation',
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Đã thêm "$word" vào danh sách từ vựng yêu thích'),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Lưu từ vựng thất bại: $e')));
    }
  }

  // ===== Chế độ dịch trực tiếp (Start / Stop) =====

  Future<void> _toggleLiveTranslate() async {
    if (_sourceLang == null || _targetLang == null) return;
    if (_isLiveTranslating) {
      await _stopLiveTranslate();
    } else {
      await _startLiveTranslate();
    }
  }

  Future<void> _startLiveTranslate() async {
    if (_sourceLang == null) return;

    setState(() {
      _isLiveTranslating = true;
      _inputController.clear();
      _translatedText = '';
      _sessionSegments.clear();
      _sessionStartedAt = DateTime.now();
      _clearWordSelections();
    });

    try {
      // 1. Lấy model Vosk Admin đã cấu hình cho ngôn ngữ nguồn (kể cả file upload thật hoặc link ngoài).
      // ModelService tự cache lại config này; nếu backend không gọi được (tắt backend/mất
      // mạng) nhưng máy đã từng lấy thành công trước đó, sẽ tự dùng lại config đã cache.
      final ModelConfig? voskModel;
      try {
        voskModel = await _modelService.getActiveVoskModel(_sourceLang!.code);
      } catch (_) {
        throw Exception(
          'Không kết nối được backend và chưa có cấu hình model nào được lưu sẵn trên máy. '
          'Cần mở backend ít nhất 1 lần để tải cấu hình trước khi dùng offline.',
        );
      }
      if (voskModel == null) {
        throw Exception(
          'Chưa có model Vosk nào được cấu hình cho "${_sourceLang!.name}" (thêm ở Web Admin → Ngôn ngữ & Model)',
        );
      }
      // Gán ra biến non-null riêng: Dart không giữ suy luận non-null của
      // `voskModel` bên trong closure (setState/callback) phía dưới.
      final ModelConfig resolvedVoskModel = voskModel;
      final modelUrl = _modelService.getDownloadUrl(resolvedVoskModel);
      if (modelUrl == null || modelUrl.isEmpty) {
        throw Exception(
          'Model Vosk "${resolvedVoskModel.name}" chưa có file hoặc link tải hợp lệ',
        );
      }

      // 2. Tải (nếu cần) + nạp model - có thể mất vài giây/phút lần đầu tùy dung lượng
      if (mounted) setState(() => _downloadingModelLabel = resolvedVoskModel.name);
      await _voskService.loadModel(modelUrl);
      if (mounted) setState(() => _downloadingModelLabel = null);

      // 3. Bắt đầu nghe mic thật, tự động dịch mỗi khi nhận diện xong 1 câu
      await _voskService.startListening(
        onPartial: (partialText) {
          if (mounted) setState(() => _inputController.text = partialText);
        },
        onResult: (finalText) => _onSpeechRecognized(finalText),
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLiveTranslating = false;
          _downloadingModelLabel = null;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Không thể bắt đầu dịch trực tiếp: $e')),
        );
      }
    }
  }

  Future<void> _stopLiveTranslate() async {
    await _voskService.stopListening();
    if (!mounted) return;
    setState(() => _isLiveTranslating = false);

    // Kết thúc phiên (Dừng) -> lưu TOÀN BỘ các lượt nói trong phiên này thành
    // 1 mục lịch sử "conversation" duy nhất (không lưu riêng lẻ từng câu nữa).
    if (_sessionSegments.isNotEmpty &&
        _sourceLang != null &&
        _targetLang != null) {
      final segmentsToSave = List<HistorySegment>.from(_sessionSegments);
      final startedAt = _sessionStartedAt ?? segmentsToSave.first.at;
      final endedAt = DateTime.now();
      _sessionSegments.clear();
      _sessionStartedAt = null;
      _ignoreHistoryFailure(
        _historyService.createConversationHistory(
          sourceLanguage: _sourceLang!.code,
          targetLanguage: _targetLang!.code,
          segments: segmentsToSave,
          startedAt: startedAt,
          endedAt: endedAt,
        ),
      );
    }
  }

  /// Được gọi mỗi khi nhận diện được 1 câu hoàn chỉnh trong lúc dịch trực tiếp.
  /// Tự động dịch ngay và cập nhật kết quả; câu này được gom vào phiên hiện tại,
  /// chỉ lưu thành lịch sử khi người dùng bấm Dừng (gộp cả phiên thành 1 mục).
  Future<void> _onSpeechRecognized(String recognizedText) async {
    if (recognizedText.trim().isEmpty) return;
    setState(() {
      _inputController.text = recognizedText;
      _clearWordSelections();
    });

    try {
      final result = await _translate(recognizedText);
      if (!mounted) return;
      setState(() => _translatedText = result);
      _sessionSegments.add(
        HistorySegment(sourceText: recognizedText, translatedText: result),
      );

      // Tự động đọc to bản dịch để có trải nghiệm "dịch trực tiếp" 2 chiều
      _speak(result, _targetLang?.code);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Dịch thất bại: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loadingLanguages) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dịch'),
        actions: [
          if (_isLiveTranslating)
            Padding(
              padding: const EdgeInsets.only(right: AppTheme.spaceMd),
              child: Row(
                children: [
                  _buildLiveDot(),
                  const SizedBox(width: 6),
                  const Text(
                    'Đang nghe',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
                  ),
                ],
              ),
            ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppTheme.spaceMd,
            4,
            AppTheme.spaceMd,
            AppTheme.spaceMd,
          ),
          child: Column(
            children: [
              _buildLanguageSelector(),
              const SizedBox(height: AppTheme.spaceMd),
              if (_downloadingModelLabel != null) _buildDownloadingBanner(),
              _buildInputCard(),
              const SizedBox(height: AppTheme.spaceMd),
              _buildLiveTranslateButton(),
              const SizedBox(height: AppTheme.spaceMd),
              if (_translatedText.isNotEmpty) _buildResultCard(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDownloadingBanner() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: AppTheme.spaceMd),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppTheme.coralTint,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.coral.withValues(alpha: .2)),
      ),
      child: Row(
        children: [
          const SizedBox(
            height: 16,
            width: 16,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Đang chuẩn bị model "$_downloadingModelLabel" · chỉ tải một lần',
              style: const TextStyle(
                fontSize: 12.5,
                color: AppTheme.moss,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLanguageSelector() {
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 8),
      decoration: BoxDecoration(
        color: AppTheme.sand,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(color: AppTheme.line),
      ),
      child: Row(
        children: [
          Expanded(
            child: _languageDropdown(
              _sourceLang,
              (v) => setState(() => _sourceLang = v),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: IconButton(
              tooltip: 'Đổi chiều dịch',
              style: IconButton.styleFrom(backgroundColor: AppTheme.ivory),
              icon: const Icon(Icons.swap_horiz_rounded, size: 20),
              onPressed: _isLiveTranslating ? null : _swapLanguages,
            ),
          ),
          Expanded(
            child: _languageDropdown(
              _targetLang,
              (v) => setState(() => _targetLang = v),
            ),
          ),
        ],
      ),
    );
  }

  Widget _languageDropdown(
    LanguageModel? value,
    ValueChanged<LanguageModel?> onChanged,
  ) {
    return DropdownButtonFormField<LanguageModel>(
      initialValue: value,
      isExpanded: true,
      icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 20),
      decoration: const InputDecoration(
        labelText: 'Ngôn ngữ',
        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        filled: true,
        fillColor: AppTheme.ivory,
      ),
      items: _languages
          .map(
            (l) => DropdownMenuItem(
              value: l,
              child: Text(l.name, overflow: TextOverflow.ellipsis),
            ),
          )
          .toList(),
      onChanged: _isLiveTranslating ? null : onChanged,
    );
  }

  Widget _buildInputCard() {
    return Card(
      color: AppTheme.ivory,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 12, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.edit_note_rounded,
                  size: 18,
                  color: AppTheme.coral,
                ),
                const SizedBox(width: 7),
                Text(
                  _isLiveTranslating
                      ? 'Đang nhận giọng nói'
                      : 'Câu bạn muốn dịch',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    color: AppTheme.moss,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            TextField(
              controller: _inputController,
              maxLines: 4,
              minLines: 3,
              readOnly: _isLiveTranslating,
              decoration: InputDecoration(
                hintText: _isLiveTranslating
                    ? 'Đang nghe...'
                    : 'Viết hoặc nói điều gì đó…',
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 6),
                hintStyle: TextStyle(
                  color: AppTheme.moss.withValues(alpha: .42),
                  fontSize: 17,
                  height: 1.35,
                ),
              ),
              style: const TextStyle(
                fontFamily: 'serif',
                fontSize: 19,
                height: 1.35,
                color: AppTheme.moss,
              ),
            ),
            if (!_isLiveTranslating)
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: _isTranslating ? null : _handleTranslateOnce,
                  icon: _isTranslating
                      ? const SizedBox(
                          height: 14,
                          width: 14,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.arrow_forward_rounded, size: 16),
                  label: const Text('Dịch câu này'),
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// Nút chính: Bắt đầu / Dừng dịch trực tiếp bằng giọng nói.
  Widget _buildLiveTranslateButton() {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: FilledButton.icon(
        onPressed: _toggleLiveTranslate,
        style: FilledButton.styleFrom(
          backgroundColor:
              _isLiveTranslating ? AppTheme.cranberry : AppTheme.coral,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(17),
          ),
        ),
        icon: Icon(
          _isLiveTranslating
              ? Icons.stop_circle_outlined
              : Icons.mic_none_rounded,
          size: 23,
        ),
        label: Text(
          _isLiveTranslating
              ? 'Dừng nghe & dịch'
              : 'Bắt đầu dịch bằng giọng nói',
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900),
        ),
      ),
    );
  }

  /// 1 nhóm từ (câu gốc hoặc câu dịch) cho phép CHỌN NHIỀU từ liên tiếp để
  /// ghép thành 1 cụm từ trước khi lưu (vd: từ ghép "đàn bà" gồm 2 âm tiết).
  Widget _buildWordGroup({
    required String label,
    required List<String> words,
    required Set<int> selectedIdx,
    required bool isFromSourceText,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            color: AppTheme.moss,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 4),
        Wrap(
          spacing: 4,
          runSpacing: 4,
          children: List.generate(words.length, (i) {
            final selected = selectedIdx.contains(i);
            return FilterChip(
              label: Text(words[i]),
              selected: selected,
              onSelected: (_) =>
                  _toggleWordSelection(i, isSourceText: isFromSourceText),
            );
          }),
        ),
        if (selectedIdx.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: FilledButton.tonalIcon(
              onPressed: () => _saveSelectedPhrase(
                words,
                isFromSourceText: isFromSourceText,
              ),
              icon: const Icon(Icons.bookmark_add_outlined, size: 16),
              label: Text(
                'Lưu cụm từ đã chọn: "${_buildSelectedPhrase(words, selectedIdx)}"',
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildResultCard() {
    final sourceWords = _inputController.text
        .trim()
        .split(RegExp(r'\s+'))
        .map((w) => w.replaceAll(RegExp(r'[^\wÀ-ỹ]'), ''))
        .where((w) => w.isNotEmpty)
        .toList();
    final translatedWords = _translatedText
        .trim()
        .split(RegExp(r'\s+'))
        .map((w) => w.replaceAll(RegExp(r'[^\wÀ-ỹ]'), ''))
        .where((w) => w.isNotEmpty)
        .toList();
    return Expanded(
      child: Card(
        color: AppTheme.sand,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Text(
                        'Bản dịch',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                          color: AppTheme.moss,
                        ),
                      ),
                      if (_isLiveTranslating) ...[
                        const SizedBox(width: 8),
                        _buildLiveDot(),
                      ],
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.volume_up_outlined),
                    onPressed: () => _speak(_translatedText, _targetLang?.code),
                    tooltip: 'Chuyển văn bản thành giọng nói',
                  ),
                ],
              ),
              const Divider(),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (sourceWords.isNotEmpty)
                        _buildWordGroup(
                          label: 'Câu gốc (${_sourceLang?.name ?? ''})',
                          words: sourceWords,
                          selectedIdx: _selectedSourceWordIdx,
                          isFromSourceText: true,
                        ),
                      if (sourceWords.isNotEmpty) const SizedBox(height: 12),
                      if (translatedWords.isNotEmpty)
                        _buildWordGroup(
                          label: 'Câu dịch (${_targetLang?.name ?? ''})',
                          words: translatedWords,
                          selectedIdx: _selectedTargetWordIdx,
                          isFromSourceText: false,
                        ),
                    ],
                  ),
                ),
              ),
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text(
                  'Chạm vào từ để chọn và lưu cụm từ vào sổ tay của bạn.',
                  style: TextStyle(
                    fontSize: 11,
                    color: AppTheme.moss,
                    height: 1.35,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLiveDot() {
    return Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.error,
        shape: BoxShape.circle,
      ),
    );
  }
}
