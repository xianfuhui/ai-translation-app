import 'package:google_mlkit_translation/google_mlkit_translation.dart';

/// Dịch văn bản offline bằng Google ML Kit Translation.
///
/// Mã ngôn ngữ truyền vào (`sourceCode`, `targetCode`) là mã BCP-47 chuẩn ML Kit
/// hỗ trợ (vd "en", "vi", "ja"...) - thường lấy từ trường `identifier` của model
/// loại "mlkit" mà Admin đã cấu hình trong kho Model (xem `ModelService`).
class TranslationService {
  OnDeviceTranslator? _translator;
  String? _cachedSourceCode;
  String? _cachedTargetCode;
  final _modelManager = OnDeviceTranslatorModelManager();

  TranslateLanguage? _languageFromCode(String code) {
    try {
      return TranslateLanguage.values.firstWhere((l) => l.bcpCode == code);
    } catch (_) {
      return null; // Ngôn ngữ này ML Kit chưa hỗ trợ
    }
  }

  bool isSupported(String code) => _languageFromCode(code) != null;

  Future<bool> isModelDownloaded(String code) async {
    final lang = _languageFromCode(code);
    if (lang == null) return false;
    return _modelManager.isModelDownloaded(lang.bcpCode);
  }

  Future<void> downloadModel(String code) async {
    final lang = _languageFromCode(code);
    if (lang == null) {
      throw Exception('Ngôn ngữ "$code" chưa được ML Kit hỗ trợ');
    }
    await _modelManager.downloadModel(lang.bcpCode);
  }

  Future<void> deleteModel(String code) async {
    final lang = _languageFromCode(code);
    if (lang == null) return;
    await _modelManager.deleteModel(lang.bcpCode);
  }

  Future<String> translate({
    required String text,
    required String sourceCode,
    required String targetCode,
  }) async {
    final sourceLang = _languageFromCode(sourceCode);
    final targetLang = _languageFromCode(targetCode);
    if (sourceLang == null || targetLang == null) {
      throw Exception('Ngôn ngữ "$sourceCode" hoặc "$targetCode" chưa được ML Kit hỗ trợ');
    }

    // Tái sử dụng translator nếu cùng cặp ngôn ngữ, tránh khởi tạo lại tốn tài nguyên
    if (_translator == null || _cachedSourceCode != sourceCode || _cachedTargetCode != targetCode) {
      _translator?.close();
      _translator = OnDeviceTranslator(sourceLanguage: sourceLang, targetLanguage: targetLang);
      _cachedSourceCode = sourceCode;
      _cachedTargetCode = targetCode;
    }

    return _translator!.translateText(text);
  }

  void dispose() {
    _translator?.close();
  }
}
