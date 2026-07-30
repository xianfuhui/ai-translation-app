import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import '../../models/language.dart';
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
  String? _downloadingModelLabel; // hiện khi đang tải model ML Kit / Vosk lần đầu

  // Trạng thái chế độ dịch trực tiếp (start/stop)
  bool _isLiveTranslating = false;

  @override
  void dispose() {
    _inputController.dispose();
    _tts.stop();
    _translationService.dispose();
    _voskService.dispose();
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
    if (_isLiveTranslating) return; // không đổi ngôn ngữ khi đang dịch trực tiếp
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
  Future<void> _ensureModelDownloaded(String mlkitCode, String displayName) async {
    if (!_translationService.isSupported(mlkitCode)) {
      throw Exception('ML Kit chưa hỗ trợ ngôn ngữ "$mlkitCode" (cấu hình lại ở Web Admin → Model)');
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

  /// Dịch văn bản offline bằng ML Kit, tự tải model ngôn ngữ nếu máy chưa có.
  Future<String> _translate(String text) async {
    if (_sourceLang == null || _targetLang == null) return text;

    final sourceCode = await _resolveMlkitCode(_sourceLang!.code);
    final targetCode = await _resolveMlkitCode(_targetLang!.code);

    await _ensureModelDownloaded(sourceCode, _sourceLang!.name);
    await _ensureModelDownloaded(targetCode, _targetLang!.name);

    return _translationService.translate(text: text, sourceCode: sourceCode, targetCode: targetCode);
  }

  /// Dịch 1 lần đoạn text hiện có trong ô nhập (dùng khi gõ tay, không ở chế độ trực tiếp)
  Future<void> _handleTranslateOnce() async {
    final text = _inputController.text.trim();
    if (text.isEmpty || _sourceLang == null || _targetLang == null) return;

    setState(() => _isTranslating = true);
    try {
      final result = await _translate(text);
      if (!mounted) return;
      setState(() => _translatedText = result);
      _saveToHistory(text, result);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Dịch thất bại: $e')));
    } finally {
      if (mounted) setState(() => _isTranslating = false);
    }
  }

  void _saveToHistory(String sourceText, String translatedText, {String type = 'text'}) {
    if (_sourceLang == null || _targetLang == null) return;
    // Lưu lịch sử (Online - best effort, không chặn UI nếu lỗi mạng)
    _historyService
        .createHistory(
          sourceLanguage: _sourceLang!.code,
          targetLanguage: _targetLang!.code,
          sourceText: sourceText,
          translatedText: translatedText,
          type: type,
        )
        .catchError((_) {});
  }

  Future<void> _speak(String text, String? langCode) async {
    if (text.isEmpty) return;
    if (langCode != null) await _tts.setLanguage(langCode);
    await _tts.speak(text);
  }

  Future<void> _saveWordAsVocabulary(String word) async {
    if (word.trim().isEmpty) return;

    // Bắt buộc phải có nghĩa/bản dịch đi kèm từ gốc khi thêm vào danh sách từ vựng
    final formKey = GlobalKey<FormState>();
    final meaningController = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Lưu từ "$word"'),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: meaningController,
            autofocus: true,
            decoration: const InputDecoration(labelText: 'Nghĩa của từ *'),
            validator: (v) => (v == null || v.trim().isEmpty) ? 'Vui lòng nhập nghĩa của từ' : null,
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Hủy')),
          FilledButton(
            onPressed: () {
              if (formKey.currentState!.validate()) Navigator.pop(context, true);
            },
            child: const Text('Lưu'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await _vocabularyService.saveVocabulary(
        word: word,
        meaning: meaningController.text.trim(),
        sourceLanguage: _sourceLang?.code,
        targetLanguage: _targetLang?.code,
        source: 'conversation',
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Đã lưu "$word" vào từ vựng yêu thích')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Lưu từ vựng thất bại: $e')));
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
    });

    try {
      // 1. Lấy model Vosk Admin đã cấu hình cho ngôn ngữ nguồn (kể cả file upload thật hoặc link ngoài)
      final voskModel = await _modelService.getActiveVoskModel(_sourceLang!.code);
      if (voskModel == null) {
        throw Exception(
          'Chưa có model Vosk nào được cấu hình cho "${_sourceLang!.name}" (thêm ở Web Admin → Ngôn ngữ & Model)',
        );
      }
      final modelUrl = _modelService.getDownloadUrl(voskModel);
      if (modelUrl == null || modelUrl.isEmpty) {
        throw Exception('Model Vosk "${voskModel.name}" chưa có file hoặc link tải hợp lệ');
      }

      // 2. Tải (nếu cần) + nạp model - có thể mất vài giây/phút lần đầu tùy dung lượng
      if (mounted) setState(() => _downloadingModelLabel = voskModel.name);
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
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Không thể bắt đầu dịch trực tiếp: $e')));
      }
    }
  }

  Future<void> _stopLiveTranslate() async {
    await _voskService.stopListening();
    if (!mounted) return;
    setState(() => _isLiveTranslating = false);
  }

  /// Được gọi mỗi khi nhận diện được 1 câu hoàn chỉnh trong lúc dịch trực tiếp.
  /// Tự động dịch ngay và cập nhật kết quả, không cần thao tác thêm.
  Future<void> _onSpeechRecognized(String recognizedText) async {
    if (recognizedText.trim().isEmpty) return;
    setState(() => _inputController.text = recognizedText);

    try {
      final result = await _translate(recognizedText);
      if (!mounted) return;
      setState(() => _translatedText = result);
      _saveToHistory(recognizedText, result, type: 'speech');

      // Tự động đọc to bản dịch để có trải nghiệm "dịch trực tiếp" 2 chiều
      _speak(result, _targetLang?.code);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Dịch thất bại: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loadingLanguages) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Dịch ngôn ngữ')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              _buildLanguageSelector(),
              const SizedBox(height: 16),
              if (_downloadingModelLabel != null) _buildDownloadingBanner(),
              _buildInputCard(),
              const SizedBox(height: 16),
              _buildLiveTranslateButton(),
              const SizedBox(height: 16),
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
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Đang tải model dịch "$_downloadingModelLabel" (chỉ tải 1 lần)...',
              style: TextStyle(fontSize: 12.5, color: Theme.of(context).colorScheme.onPrimaryContainer),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLanguageSelector() {
    return Row(
      children: [
        Expanded(child: _languageDropdown(_sourceLang, (v) => setState(() => _sourceLang = v))),
        IconButton(icon: const Icon(Icons.swap_horiz), onPressed: _isLiveTranslating ? null : _swapLanguages),
        Expanded(child: _languageDropdown(_targetLang, (v) => setState(() => _targetLang = v))),
      ],
    );
  }

  Widget _languageDropdown(LanguageModel? value, ValueChanged<LanguageModel?> onChanged) {
    return DropdownButtonFormField<LanguageModel>(
      value: value,
      isExpanded: true,
      decoration: const InputDecoration(border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 12)),
      items: _languages.map((l) => DropdownMenuItem(value: l, child: Text(l.name, overflow: TextOverflow.ellipsis))).toList(),
      onChanged: _isLiveTranslating ? null : onChanged,
    );
  }

  Widget _buildInputCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _inputController,
              maxLines: 4,
              readOnly: _isLiveTranslating, // đang dịch trực tiếp thì text được đổ vào tự động từ mic
              decoration: InputDecoration(
                hintText: _isLiveTranslating ? 'Đang nghe...' : 'Nhập văn bản cần dịch, hoặc bấm Dịch để nói',
                border: InputBorder.none,
              ),
            ),
            if (!_isLiveTranslating)
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton.icon(
                    onPressed: _isTranslating ? null : _handleTranslateOnce,
                    icon: _isTranslating
                        ? const SizedBox(height: 14, width: 14, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.text_fields, size: 16),
                    label: const Text('Dịch văn bản đã gõ'),
                  ),
                ],
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
      height: 52,
      child: FilledButton.icon(
        onPressed: _toggleLiveTranslate,
        style: FilledButton.styleFrom(
          backgroundColor: _isLiveTranslating ? Theme.of(context).colorScheme.error : null,
        ),
        icon: Icon(_isLiveTranslating ? Icons.stop_circle_outlined : Icons.mic, size: 22),
        label: Text(
          _isLiveTranslating ? 'Dừng dịch trực tiếp' : 'Dịch',
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  Widget _buildResultCard() {
    final words = _translatedText.split(RegExp(r'\s+'));
    return Expanded(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Text('Kết quả', style: TextStyle(fontWeight: FontWeight.w600)),
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
                  child: Wrap(
                    spacing: 4,
                    runSpacing: 4,
                    children: words
                        .map((w) => ActionChip(
                              label: Text(w),
                              onPressed: () => _saveWordAsVocabulary(w.replaceAll(RegExp(r'[^\wÀ-ỹ]'), '')),
                            ))
                        .toList(),
                  ),
                ),
              ),
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text(
                  'Chạm vào 1 từ để lưu vào từ vựng yêu thích',
                  style: TextStyle(fontSize: 11, color: Colors.grey),
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
      decoration: BoxDecoration(color: Theme.of(context).colorScheme.error, shape: BoxShape.circle),
    );
  }
}
