import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_tts/flutter_tts.dart';
import '../../core/local_store.dart';
import '../../core/offline_packs.dart';
import '../../core/theme.dart';
import '../../models/language.dart';
import '../../models/history.dart';
import '../../models/model_config.dart';
import '../../services/language_service.dart';
import '../../services/history_service.dart';
import '../../services/translation_service.dart';
import '../../services/model_service.dart';
import '../../services/vosk_service.dart';
import '../../widgets/brand_mark.dart';
import '../../widgets/connection_banner.dart';
import '../home_screen.dart';

/// Màn hình Dịch — MÀN HÌNH CHÍNH của app (UI v2).
///
/// Thay đổi so với v1:
/// - Mở app là dịch được ngay: ô nhập luôn hiện, TỰ DỊCH khi gõ (debounce),
///   không còn nút "Dịch câu này".
/// - Lịch sử nằm ở tab riêng (HistoryScreen).
/// - Kết quả hiện trong card XANH ĐẬM với nút 🔊 phát âm + sao chép.
/// - Chips TỪ NGUỒN bên dưới kết quả: chạm từ để lưu vào sổ tay (từ đã lưu
///   được tô viền xanh). Lịch sử chỉ lưu khi "chốt" câu (xoá ô nhập / đổi
///   chiều / mở câu khác) để auto-translate không spam mỗi ký tự.
///
/// OFFLINE (giữ nguyên từ v1): danh sách ngôn ngữ cache; dịch bằng ML Kit
/// on-device (model tự tải lần đầu); TTS hệ thống qua flutter_tts.
///
/// DỊCH GIỌNG NÓI (chỉ Android — vosk_flutter không có iOS): nút "Nói để dịch"
/// trong ô nhập bật/tắt phiên nghe liên tục; mỗi câu nhận diện xong tự dịch +
/// đọc to; cả phiên được lưu thành MỘT mục lịch sử "conversation" khi Dừng.
class TranslateScreen extends StatefulWidget {
  const TranslateScreen({super.key});

  @override
  State<TranslateScreen> createState() => _TranslateScreenState();
}

class _TranslateScreenState extends State<TranslateScreen> {
  final _languageService = LanguageService();
  final _historyService = HistoryService();
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
  String? _downloadingModelLabel;
  double? _downloadProgress; // null = chưa biết % (thanh chạy)
  CancelToken? _downloadCancel;

  // Auto-translate khi gõ: debounce để không dịch từng ký tự.
  Timer? _debounce;
  static const _debounceDelay = Duration(milliseconds: 350);

  // --- Tăng tốc dịch ---
  // Số thứ tự lượt dịch: kết quả của lượt cũ (đến muộn) bị bỏ, không đè câu mới.
  int _translateSeq = 0;
  // Bộ nhớ 50 bản dịch gần nhất: gõ lại / đảo chiều / xoá rồi gõ lại -> hiện ngay.
  final _translationCache = <String, String>{};
  static const _cacheSize = 50;
  // Gói ML Kit đã biết là có trên máy -> khỏi hỏi lại native mỗi lần dịch.
  final Set<String> _readyModels = {};
  String? _ttsLanguage;

  // Tự đọc to bản dịch sau mỗi câu khi ghi âm (bật/tắt, nhớ lựa chọn).
  // Tắt = mic KHÔNG bị tạm dừng nên nghe liên tục, mượt hơn.
  bool _autoSpeak = true;
  final _prefs = LocalStore();
  Future<void>? _voskPreload; // nạp sẵn model Vosk cho ngôn ngữ nguồn
  // Câu cuối cùng ĐÃ lưu lịch sử — tránh lưu trùng khi "chốt" nhiều lần.
  String _lastCommittedText = '';

  // Từ đã có trong sổ tay (lowercase) — để tô sáng chip.

  // ===== Trạng thái dịch trực tiếp (giữ nguyên logic v1) =====
  bool _isLiveTranslating = false;
  bool _micPaused = false; // mic tạm tắt (đang tải model giữa phiên nói)
  // Mic chỉ thật sự mở khi phiên đã sẵn sàng và không bị tạm dừng.
  bool get _isMicOn => _isLiveTranslating && !_isStartingLive && !_micPaused;
  bool _isStartingLive = false;
  int _liveSessionId = 0;
  Future<void> _recognitionQueue = Future.value();
  final List<HistorySegment> _sessionSegments = [];
  DateTime? _sessionStartedAt;

  @override
  void initState() {
    super.initState();
    _loadLanguages();
    _loadAutoSpeakPref();
    _tts.awaitSpeakCompletion(true);
    _inputController.addListener(_onInputChanged);
    OfflinePacks.changes.addListener(_onPacksChanged);
  }

  @override
  void dispose() {
    _liveSessionId++;
    OfflinePacks.changes.removeListener(_onPacksChanged);
    _downloadCancel?.cancel();
    _debounce?.cancel();
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

  // ===== Data bootstrap =====

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
      _warmUpTranslator();
      _preloadVosk();
    } catch (e) {
      setState(() => _loadingLanguages = false);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Không tải được danh sách ngôn ngữ: $e')),
      );
    }
  }

  // ===== Auto-translate (debounce) =====

  Future<void> _loadAutoSpeakPref() async {
    try {
      final v = await _prefs.readJson(LocalKeys.autoSpeak);
      if (v is bool && mounted) setState(() => _autoSpeak = v);
    } catch (_) {}
  }

  Future<void> _toggleAutoSpeak() async {
    final next = !_autoSpeak;
    setState(() => _autoSpeak = next);
    if (!next) await _tts.stop(); // đang đọc dở thì dừng luôn
    try {
      await _prefs.writeJson(LocalKeys.autoSpeak, next);
    } catch (_) {}
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(next
            ? 'Đã bật đọc to bản dịch khi ghi âm'
            : 'Đã tắt đọc to bản dịch khi ghi âm'),
      ));
  }

  /// Có gói được tải/xóa ở nơi khác -> bỏ các ghi nhớ cũ.
  void _onPacksChanged() {
    _readyModels.clear();
    _mlkitCodeCache.clear();
    _translationCache.clear();
  }

  /// Đang tải model -> tạm ngưng việc dịch để tập trung tải (không dịch song
  /// song, không nạp sẵn). Gõ thêm chữ vẫn được; dịch tiếp khi tải xong.
  bool get _isDownloading => _downloadingModelLabel != null;
  bool _translatePending = false;

  void _onInputChanged() {
    if (_isLiveTranslating) return; // phiên nói: text do Vosk đổ vào
    setState(() {}); // cập nhật nút ✕
    _debounce?.cancel();
    final text = _inputController.text.trim();
    if (text.isEmpty) {
      setState(() => _translatedText = '');
      return;
    }
    _debounce = Timer(_debounceDelay, _handleTranslateOnce);
  }

  Future<void> _handleTranslateOnce() async {
    final text = _inputController.text.trim();
    if (text.isEmpty || _sourceLang == null || _targetLang == null) return;
    if (_isDownloading) {
      _translatePending = true; // dịch sau khi tải xong
      return;
    }

    final from = _sourceLang!.code;
    final to = _targetLang!.code;
    final key = '$from>$to|$text';

    // Đã dịch câu này rồi -> hiện ngay, không gọi ML Kit.
    final hit = _translationCache.remove(key);
    if (hit != null) {
      _translationCache[key] = hit; // đưa lên "mới dùng gần nhất"
      _translateSeq++;
      setState(() {
        _translatedText = hit;
        _isTranslating = false;
      });
      return;
    }

    final seq = ++_translateSeq;
    setState(() => _isTranslating = true);
    try {
      final result = await _translateBetween(text, from, to);
      if (!mounted || seq != _translateSeq) return; // đã có lượt dịch mới hơn
      _translationCache[key] = result;
      if (_translationCache.length > _cacheSize) {
        _translationCache.remove(_translationCache.keys.first);
      }
      if (_inputController.text.trim() == text) {
        setState(() => _translatedText = result);
      }
    } catch (e) {
      if (!mounted || seq != _translateSeq) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_errorText(e, 'Dịch thất bại'))));
    } finally {
      if (mounted && seq == _translateSeq) setState(() => _isTranslating = false);
    }
  }

  /// "Chốt" câu hiện tại vào lịch sử (gọi khi xoá ô nhập / đổi chiều / mở câu
  /// khác) — auto-translate không tự lưu để tránh spam lịch sử mỗi ký tự.
  void _commitCurrentToHistory() {
    final text = _inputController.text.trim();
    if (text.isEmpty || _translatedText.isEmpty) return;
    if (text == _lastCommittedText) return;
    if (_sourceLang == null || _targetLang == null) return;
    _lastCommittedText = text;
    _ignoreHistoryFailure(
      _historyService.createHistory(
        sourceLanguage: _sourceLang!.code,
        targetLanguage: _targetLang!.code,
        sourceText: text,
        translatedText: _translatedText,
      ),
    );
  }

  void _clearInput() {
    _commitCurrentToHistory();
    _debounce?.cancel();
    setState(() {
      _inputController.clear();
      _translatedText = '';
    });
  }

  void _swapLanguages() {
    if (_isLiveTranslating) return;
    _commitCurrentToHistory();
    setState(() {
      final tmp = _sourceLang;
      _sourceLang = _targetLang;
      _targetLang = tmp;
    });
    if (_inputController.text.trim().isNotEmpty) _handleTranslateOnce();
    _warmUpTranslator();
    _preloadVosk();
  }

  // ===== Dịch (ML Kit, giữ nguyên v1) =====

  // Languages whose ML Kit model is already on the device never need the
  // backend again, so remember the resolved code in memory.
  final Map<String, String> _mlkitCodeCache = {};

  Future<String> _resolveMlkitCode(String languageCode) async {
    final cached = _mlkitCodeCache[languageCode];
    if (cached != null) return cached;
    // Fast path (works offline / as guest): plain code, model already downloaded.
    if (_translationService.isSupported(languageCode) &&
        await _isModelReady(languageCode)) {
      return _mlkitCodeCache[languageCode] = languageCode;
    }
    // Otherwise let an admin-configured identifier win (backend or its cache).
    // Giới hạn 2 giây: máy chủ chậm/mất mạng không được làm treo việc dịch.
    try {
      final model = await _modelService
          .getActiveMlkitModel(languageCode)
          .timeout(const Duration(seconds: 2));
      return _mlkitCodeCache[languageCode] = model?.identifier ?? languageCode;
    } catch (_) {
      return languageCode; // không cache: lần sau thử lại
    }
  }

  /// Nạp sẵn model ML Kit của cặp ngôn ngữ đang chọn (chỉ khi đã tải, không
  /// bao giờ tự tải). Gọi lúc mở màn / đổi ngôn ngữ / bắt đầu ghi âm.
  Future<void> _warmUpTranslator() async {
    final from = _sourceLang, to = _targetLang;
    if (from == null || to == null || _isDownloading) return;
    try {
      final codes = await Future.wait([
        _resolveMlkitCode(from.code),
        _resolveMlkitCode(to.code),
      ]);
      if (!_translationService.isSupported(codes[0]) ||
          !_translationService.isSupported(codes[1])) {
        return;
      }
      if (!await _isModelReady(codes[0]) || !await _isModelReady(codes[1])) return;
      await _translationService.warmUp(sourceCode: codes[0], targetCode: codes[1]);
    } catch (_) {}
  }

  /// Nạp sẵn model Vosk (nếu đã cài trên máy) để bấm "Nói để dịch" là nghe được
  /// ngay, không phải đợi nạp model. Không tải mạng, không gọi máy chủ.
  void _preloadVosk() {
    if (!VoskService.isSupported || _sourceLang == null) return;
    final code = _sourceLang!.code;
    _voskPreload = () async {
      try {
        final config = await _modelService.getInstalledVosk(code);
        if (config == null) return;
        final url = _modelService.getDownloadUrl(config);
        if (url == null || url.isEmpty) return;
        if (!await _voskService.isModelDownloaded(url)) return;
        if (_isLiveTranslating || _isStartingLive || _isDownloading) return;
        await _voskService.loadModel(url);
      } catch (_) {}
    }();
  }

  /// Gói đã có trên máy? Hỏi ML Kit (native) tối đa 1 lần cho mỗi ngôn ngữ.
  Future<bool> _isModelReady(String code) async {
    if (_readyModels.contains(code)) return true;
    final ok = await _translationService.isModelDownloaded(code);
    if (ok) _readyModels.add(code);
    return ok;
  }

  Future<void> _ensureModelDownloaded(
    String mlkitCode,
    String displayName,
  ) async {
    if (!_translationService.isSupported(mlkitCode)) {
      throw Exception(
        'ML Kit chưa hỗ trợ ngôn ngữ "$mlkitCode" (cấu hình lại ở Web Admin → Model)',
      );
    }
    if (await _isModelReady(mlkitCode)) return;
    final cancel = CancelToken();
    // Đang trong phiên nói -> tắt mic trong lúc tải để tập trung tải (và để
    // người dùng thấy rõ mic không còn bật).
    final pauseMic = _isLiveTranslating && !_isStartingLive;
    if (pauseMic) {
      await _voskService.pauseListening();
      if (mounted) setState(() => _micPaused = true);
    }
    if (mounted) {
      setState(() {
        _downloadingModelLabel = displayName;
        _downloadProgress = null; // ML Kit không báo % -> thanh chạy
        _downloadCancel = cancel;
      });
    }
    try {
      await _translationService.downloadModel(mlkitCode, cancel: cancel);
      OfflinePacks.notifyChanged(); // (xoá các ghi nhớ cũ)
      _readyModels.add(mlkitCode);
    } on DownloadCancelled {
      rethrow;
    } on NoInternetException {
      throw NoInternetException(
        'Không có mạng để tải gói ngôn ngữ "$displayName". '
        'Hãy kết nối mạng rồi thử lại (chỉ cần tải một lần).',
      );
    } catch (_) {
      throw Exception(
        'Chưa có gói ngôn ngữ "$displayName" trên máy và không tải được. '
        'Vào Cá nhân → Gói ngoại tuyến để tải trước.',
      );
    } finally {
      if (pauseMic) {
        _micPaused = false;
        if (_isLiveTranslating) await _voskService.resumeListening();
      }
      if (mounted) _clearDownloadState();
    }
  }

  void _clearDownloadState() {
    setState(() {
      _downloadingModelLabel = null;
      _downloadProgress = null;
      _downloadCancel = null;
    });
    // Tải xong (hoặc huỷ) -> dịch lại câu người dùng đã gõ trong lúc chờ.
    if (_translatePending && !_isLiveTranslating) {
      _translatePending = false;
      _handleTranslateOnce();
    }
  }

  /// Nội dung snackbar cho lỗi dịch / tải model (huỷ & không có mạng nói gọn).
  String _errorText(Object e, String prefix) {
    if (e is DownloadCancelled) return 'Đã hủy tải model';
    if (e is NoInternetException) return e.message;
    return '$prefix: $e';
  }

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
    // Hai ngôn ngữ kiểm tra song song (trước đây nối tiếp nhau).
    final resolved = await Future.wait([
      _resolveMlkitCode(fromCode),
      _resolveMlkitCode(toCode),
    ]);
    final resolvedFrom = resolved[0];
    final resolvedTo = resolved[1];
    // Tải tuần tự (chung 1 banner + 1 nút Hủy); gói đã sẵn thì qua ngay.
    await _ensureModelDownloaded(resolvedFrom, _langNameForCode(fromCode));
    await _ensureModelDownloaded(resolvedTo, _langNameForCode(toCode));
    return _translationService.translate(
      text: text,
      sourceCode: resolvedFrom,
      targetCode: resolvedTo,
    );
  }

  Future<String> _translate(String text) async {
    if (_sourceLang == null || _targetLang == null) return text;
    return _translateBetween(text, _sourceLang!.code, _targetLang!.code);
  }

  Future<void> _ignoreHistoryFailure(
    Future<TranslationHistoryItem> request,
  ) async {
    try {
      await request;
    } catch (_) {}
  }

  Future<void> _speak(String text, String? langCode) async {
    if (text.isEmpty) return;
    // Chỉ đổi ngôn ngữ đọc khi thật sự khác (mỗi lần gọi là 1 vòng qua native).
    if (langCode != null && langCode != _ttsLanguage) {
      await _tts.setLanguage(langCode);
      _ttsLanguage = langCode;
    }
    await _tts.speak(text);
  }

  Future<void> _copyResult() async {
    if (_translatedText.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: _translatedText));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Đã sao chép bản dịch')),
    );
  }

  // ===== Dịch trực tiếp bằng giọng nói (giữ nguyên logic v1) =====

  Future<void> _toggleLiveTranslate() async {
    if (_sourceLang == null || _targetLang == null) return;
    if (_isStartingLive) return;
    if (_isDownloading && !_isLiveTranslating) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Đang tải model — chờ tải xong hoặc bấm Hủy rồi hãy dịch.'),
      ));
      return;
    }
    if (_isLiveTranslating) {
      await _stopLiveTranslate();
    } else {
      await _startLiveTranslate();
    }
  }

  Future<void> _startLiveTranslate() async {
    if (_sourceLang == null) return;
    final mySessionId = ++_liveSessionId;
    bool isStale() => mySessionId != _liveSessionId;

    setState(() {
      _isStartingLive = true;
      _isLiveTranslating = true;
      _inputController.clear();
      _translatedText = '';
      _sessionSegments.clear();
      _sessionStartedAt = DateTime.now();
    });

    try {
      // Installed model -> backend/cache -> built-in default. If the model is
      // already on the device, the backend is not contacted at all.
      final ModelConfig? voskModel =
          await _modelService.getActiveVoskModel(_sourceLang!.code);
      if (isStale()) return;
      if (voskModel == null) {
        throw Exception(
          'Chưa có model giọng nói cho "${_sourceLang!.name}". '
          'Admin cần thêm model ở Web Admin, hoặc ngôn ngữ này chưa được hỗ trợ.',
        );
      }
      final ModelConfig resolvedVoskModel = voskModel;
      final modelUrl = _modelService.getDownloadUrl(resolvedVoskModel);
      if (modelUrl == null || modelUrl.isEmpty) {
        throw Exception(
          'Model Vosk "${resolvedVoskModel.name}" chưa có file hoặc link tải hợp lệ',
        );
      }
      final alreadyOnDevice = await _voskService.isModelDownloaded(modelUrl);
      if (isStale()) return;

      // Nếu model đang được nạp sẵn nền thì đợi nó xong (loadModel bên dưới sẽ
      // thấy đã nạp và trả về ngay) thay vì nạp lại lần nữa.
      await _voskPreload;
      if (isStale()) return;
      _warmUpTranslator(); // song song với lúc mở mic

      final cancel = CancelToken();
      if (mounted && !alreadyOnDevice) {
        setState(() {
          _downloadingModelLabel = resolvedVoskModel.name;
          _downloadProgress = 0;
          _downloadCancel = cancel;
        });
      }
      try {
        await _voskService.loadModel(
          modelUrl,
          cancel: cancel,
          onProgress: (p) {
            if (mounted && _downloadingModelLabel != null) {
              setState(() => _downloadProgress = p);
            }
          },
        );
        OfflinePacks.notifyChanged();
      } finally {
        if (mounted) _clearDownloadState();
      }
      // From now on this language runs fully offline, no backend lookups.
      await _modelService.markVoskInstalled(_sourceLang!.code, resolvedVoskModel);
      if (isStale()) return;

      await _voskService.startListening(
        onPartial: (partialText) {
          // Chỉ đổi chữ trong ô nhập (TextField tự vẽ lại) — không setState để
          // khỏi dựng lại cả màn hình ~10 lần/giây khi đang nói.
          if (mounted && !isStale()) _inputController.text = partialText;
        },
        onResult: (finalText) => _queueSpeechRecognized(finalText, isStale),
      );
      if (isStale()) {
        await _voskService.stopListening();
        return;
      }
    } catch (e) {
      if (mounted && !isStale()) {
        setState(() => _isLiveTranslating = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_errorText(e, 'Không thể bắt đầu dịch trực tiếp'))),
        );
      }
    } finally {
      if (mounted && !isStale()) setState(() => _isStartingLive = false);
    }
  }

  Future<void> _stopLiveTranslate() async {
    _liveSessionId++;
    _downloadCancel?.cancel();
    await _voskService.stopListening();
    if (!mounted) return;
    setState(() {
      _isLiveTranslating = false;
      _isStartingLive = false;
      _downloadingModelLabel = null;
      _downloadProgress = null;
    });

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

  void _queueSpeechRecognized(String recognizedText, bool Function() isStale) {
    _recognitionQueue = _recognitionQueue.then(
      (_) => _onSpeechRecognized(recognizedText, isStale),
    );
  }

  Future<void> _onSpeechRecognized(
    String recognizedText,
    bool Function() isStale,
  ) async {
    if (recognizedText.trim().isEmpty || isStale() || !mounted) return;
    setState(() => _inputController.text = recognizedText);

    try {
      final result = await _translate(recognizedText);
      if (!mounted || isStale()) return;
      setState(() => _translatedText = result);
      _sessionSegments.add(
        HistorySegment(sourceText: recognizedText, translatedText: result),
      );
      if (!_autoSpeak) return; // không đọc -> không cần tạm dừng mic
      await _voskService.pauseListening();
      try {
        await _speak(result, _targetLang?.code);
      } finally {
        if (!isStale()) await _voskService.resumeListening();
      }
    } catch (e) {
      if (!mounted || isStale()) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_errorText(e, 'Dịch thất bại'))));
    }
  }

  // ===== UI (v2) =====

  @override
  Widget build(BuildContext context) {
    if (_loadingLanguages) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(
                  AppTheme.spaceMd,
                  4,
                  AppTheme.spaceMd,
                  AppTheme.spaceMd,
                ),
                children: [
                  const ConnectionBanner(),
                  _buildLanguageBar(),
                  const SizedBox(height: 12),
                  if (_downloadingModelLabel != null) _buildDownloadingBanner(),
                  _buildInputCard(),
                  const SizedBox(height: 12),
                  if (_translatedText.isNotEmpty) ...[
                    _buildResultCard(),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding:
          const EdgeInsets.fromLTRB(AppTheme.spaceMd, 8, AppTheme.spaceMd, 10),
      child: Row(
        children: [
          const BrandMark(compact: true),
          if (_isMicOn) ...[
            const SizedBox(width: 12),
            _buildLiveDot(),
            const SizedBox(width: 5),
            const Text(
              'Đang nghe',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
            ),
          ],
          const Spacer(),
          if (VoskService.isSupported) ...[
            Semantics(
              button: true,
              label: _autoSpeak
                  ? 'Tắt đọc to bản dịch khi ghi âm'
                  : 'Bật đọc to bản dịch khi ghi âm',
              child: IconButton(
                tooltip: _autoSpeak
                    ? 'Đang bật đọc to bản dịch — bấm để tắt'
                    : 'Đang tắt đọc to bản dịch — bấm để bật',
                onPressed: _toggleAutoSpeak,
                icon: Icon(
                  _autoSpeak ? Icons.volume_up_rounded : Icons.volume_off_rounded,
                  color: _autoSpeak ? AppTheme.moss : AppTheme.moss.withValues(alpha: .45),
                ),
              ),
            ),
            const SizedBox(width: 4),
          ],
          Semantics(
            button: true,
            label: 'Mở trang cá nhân',
            child: InkWell(
              borderRadius: BorderRadius.circular(13),
              onTap: () => HomeTabs.of(context)?.select(4),
              child: Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppTheme.coralTint,
                  borderRadius: BorderRadius.circular(13),
                  border: Border.all(color: AppTheme.coral),
                ),
                child: const Text(
                  'N',
                  style: TextStyle(
                    color: AppTheme.coral,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLanguageBar() {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: AppTheme.sand,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Expanded(child: _buildLangButton(isSource: true)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: Semantics(
              button: true,
              label: 'Đổi chiều dịch',
              child: Material(
                color: AppTheme.ivory,
                shape: const CircleBorder(),
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: _swapLanguages,
                  child: const SizedBox(
                    width: 38,
                    height: 38,
                    child: Icon(
                      Icons.swap_horiz_rounded,
                      size: 20,
                      color: AppTheme.moss,
                    ),
                  ),
                ),
              ),
            ),
          ),
          Expanded(child: _buildLangButton(isSource: false)),
        ],
      ),
    );
  }

  Widget _buildLangButton({required bool isSource}) {
    final lang = isSource ? _sourceLang : _targetLang;
    return Semantics(
      button: true,
      label: isSource ? 'Chọn ngôn ngữ nguồn' : 'Chọn ngôn ngữ đích',
      child: _buildLangButtonBody(lang, isSource),
    );
  }

  Widget _buildLangButtonBody(LanguageModel? lang, bool isSource) {
    return Material(
      color: AppTheme.ivory,
      borderRadius: BorderRadius.circular(13),
      child: InkWell(
        borderRadius: BorderRadius.circular(13),
        onTap:
            _isLiveTranslating ? null : () => _pickLanguage(isSource: isSource),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(13),
            border: Border.all(color: AppTheme.line),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(
                  lang?.name ?? '—',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.moss,
                  ),
                ),
              ),
              const Icon(
                Icons.arrow_drop_down_rounded,
                size: 20,
                color: AppTheme.moss,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickLanguage({required bool isSource}) async {
    final picked = await showModalBottomSheet<LanguageModel>(
      context: context,
      showDragHandle: true,
      builder: (context) => ListView(
        children: _languages
            .map(
              (l) => ListTile(
                title: Text(
                  l.name,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                trailing: (isSource ? _sourceLang : _targetLang)?.code == l.code
                    ? const Icon(Icons.check_rounded, color: AppTheme.coral)
                    : null,
                onTap: () => Navigator.pop(context, l),
              ),
            )
            .toList(),
      ),
    );
    if (picked == null) return;
    setState(() {
      if (isSource) {
        _sourceLang = picked;
      } else {
        _targetLang = picked;
      }
    });
    if (_inputController.text.trim().isNotEmpty) _handleTranslateOnce();
    _warmUpTranslator();
    if (isSource) _preloadVosk();
  }

  Widget _buildDownloadingBanner() {
    final p = _downloadProgress;
    final percent = p == null ? '' : ' · ${(p * 100).clamp(0, 100).round()}%';
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.fromLTRB(14, 12, 6, 12),
      decoration: BoxDecoration(
        color: AppTheme.coralTint,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.coral.withValues(alpha: .2)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Đang tải model "$_downloadingModelLabel"$percent',
                  style: const TextStyle(
                    fontSize: 12.5,
                    color: AppTheme.moss,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Việc dịch tạm dừng cho đến khi tải xong.',
                  style: TextStyle(
                    fontSize: 11.5,
                    color: AppTheme.moss.withValues(alpha: .6),
                  ),
                ),
                const SizedBox(height: 6),
                // p == null: chưa biết dung lượng -> thanh chạy liên tục.
                LinearProgressIndicator(value: p, minHeight: 4),
              ],
            ),
          ),
          TextButton(
            onPressed: _downloadCancel == null || _downloadCancel!.isCancelled
                ? null
                : () {
                    _translatePending = false; // huỷ -> đừng tự dịch lại
                    _downloadCancel!.cancel();
                  },
            child: const Text('Hủy'),
          ),
        ],
      ),
    );
  }

  Widget _buildInputCard() {
    final hasInput = _inputController.text.trim().isNotEmpty;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
      decoration: BoxDecoration(
        color: AppTheme.ivory,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _inputController,
            readOnly: _isLiveTranslating,
            minLines: 2,
            maxLines: 5,
            style: const TextStyle(fontSize: 19, height: 1.45),
            decoration: const InputDecoration(
              hintText: 'Nhập văn bản…',
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              filled: false,
              contentPadding: EdgeInsets.zero,
            ),
          ),
          const Divider(height: 18),
          Row(
            children: [
              if (VoskService.isSupported)
                _buildVoicePill()
              else
                Row(
                  children: [
                    Icon(
                      Icons.mic_off_rounded,
                      size: 14,
                      color: AppTheme.moss.withValues(alpha: .45),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      'Voice chỉ có trên Android (Vosk)',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.moss.withValues(alpha: .45),
                      ),
                    ),
                  ],
                ),
              const Spacer(),
              if (_isTranslating)
                const Padding(
                  padding: EdgeInsets.only(right: 8),
                  child: SizedBox(
                    height: 14,
                    width: 14,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              if (hasInput && !_isLiveTranslating)
                Semantics(
                  button: true,
                  label: 'Xóa ô nhập',
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: _clearInput,
                    child: Container(
                      width: 30,
                      height: 30,
                      alignment: Alignment.center,
                      decoration: const BoxDecoration(
                        color: AppTheme.sand,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.close_rounded,
                        size: 16,
                        color: AppTheme.moss,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildVoicePill() {
    final preparing = _isStartingLive;
    final recording = _isMicOn;
    final label = preparing
        ? (_downloadingModelLabel != null ? 'Đang tải model…' : 'Đang chuẩn bị…')
        : (_micPaused
            ? 'Mic tạm tắt (đang tải)'
            : (_isLiveTranslating ? 'Dừng nghe' : 'Nói để dịch'));
    final fg = recording ? AppTheme.ivory : AppTheme.cranberry;
    return Material(
      // Đỏ chỉ khi mic THẬT SỰ đang mở; đang tải/chuẩn bị thì nền nhạt.
      color: recording ? AppTheme.cranberry : AppTheme.coralTint,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: preparing ? null : _toggleLiveTranslate,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (preparing)
                SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2, color: fg),
                )
              else
                Icon(
                  recording
                      ? Icons.stop_circle_outlined
                      : (_micPaused ? Icons.mic_off_rounded : Icons.mic_none_rounded),
                  size: 16,
                  color: fg,
                ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: fg,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildResultCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.moss,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                (_targetLang?.name ?? 'BẢN DỊCH').toUpperCase(),
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.1,
                  color: AppTheme.ivory.withValues(alpha: .55),
                ),
              ),
              const Spacer(),
              _buildResultIcon(
                Icons.volume_up_rounded,
                'Phát âm',
                () => _speak(_translatedText, _targetLang?.code),
              ),
              const SizedBox(width: 8),
              _buildResultIcon(Icons.copy_rounded, 'Sao chép', _copyResult),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            _translatedText,
            style: const TextStyle(
              color: AppTheme.ivory,
              fontSize: 21,
              fontWeight: FontWeight.w700,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResultIcon(IconData icon, String tooltip, VoidCallback onTap) {
    return Material(
      color: AppTheme.ivory.withValues(alpha: .12),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: 32,
          height: 32,
          child: Icon(icon,
              size: 15, color: AppTheme.ivory, semanticLabel: tooltip),
        ),
      ),
    );
  }

  Widget _buildLiveDot() {
    return Container(
      width: 8,
      height: 8,
      decoration: const BoxDecoration(
        color: AppTheme.cranberry,
        shape: BoxShape.circle,
      ),
    );
  }
}
