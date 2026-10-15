import 'package:google_mlkit_translation/google_mlkit_translation.dart';
import '../core/offline_packs.dart';

/// Dịch văn bản offline bằng Google ML Kit Translation.
///
/// Mã ngôn ngữ truyền vào (`sourceCode`, `targetCode`) là mã BCP-47 chuẩn ML Kit
/// hỗ trợ (vd "en", "vi", "ja"...) - thường lấy từ trường `identifier` của model
/// loại "mlkit" mà Admin đã cấu hình trong kho Model (xem `ModelService`).
class TranslationService {
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

  /// Tải gói dịch. ML Kit không báo % tiến độ nên UI chỉ hiện thanh chạy
  /// (indeterminate). [cancel] dừng việc chờ: ML Kit không cho huỷ hẳn phần
  /// tải đang chạy dưới nền, nên nếu nó kịp tải xong thì gói vẫn nằm trên máy.
  Future<void> downloadModel(String code, {CancelToken? cancel}) async {
    final lang = _languageFromCode(code);
    if (lang == null) {
      throw Exception('Ngôn ngữ "$code" chưa được ML Kit hỗ trợ');
    }
    if (!await OfflinePacks.hasInternet()) throw const NoInternetException();
    cancel?.throwIfCancelled();

    // isWifiRequired: false -> cho phép tải bằng dữ liệu di động (mặc định của
    // ML Kit là chỉ tải khi có Wi-Fi).
    final download = _modelManager.downloadModel(lang.bcpCode, isWifiRequired: false);
    if (cancel == null) {
      await download;
      return;
    }
    // Tránh "unhandled error" nếu người dùng đã huỷ rồi nó mới lỗi.
    final guarded = download.then((ok) => ok).catchError((_) => false);
    await Future.any<Object?>([guarded, cancel.whenCancelled]);
    cancel.throwIfCancelled();
    if (!await guarded) throw const NoInternetException('Tải gói ngôn ngữ thất bại.');
  }

  Future<void> deleteModel(String code) async {
    final lang = _languageFromCode(code);
    if (lang == null) return;
    await _modelManager.deleteModel(lang.bcpCode);
  }

  /// Giữ tối đa [_maxTranslators] translator (mỗi cặp ngôn ngữ 1 cái). Nhờ vậy
  /// đảo chiều en↔vi hay dịch song song với warm-up không phải đóng/mở lại
  /// translator (mỗi lần mở lại phải nạp model vào bộ nhớ).
  static const _maxTranslators = 4;
  final Map<String, OnDeviceTranslator> _translators = {};

  OnDeviceTranslator _translatorFor(
    TranslateLanguage source,
    TranslateLanguage target,
  ) {
    final key = '${source.bcpCode}>${target.bcpCode}';
    final existing = _translators.remove(key);
    if (existing != null) {
      _translators[key] = existing; // mới dùng gần nhất
      return existing;
    }
    final created = OnDeviceTranslator(sourceLanguage: source, targetLanguage: target);
    _translators[key] = created;
    while (_translators.length > _maxTranslators) {
      final oldest = _translators.keys.first;
      _translators.remove(oldest)?.close();
    }
    return created;
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
    return _translatorFor(sourceLang, targetLang).translateText(text);
  }

  /// Nạp sẵn model của cặp ngôn ngữ vào bộ nhớ (dịch 1 ký tự bỏ đi) để câu dịch
  /// THẬT đầu tiên không bị khựng 1–2 giây. Chỉ nên gọi khi gói đã có trên máy.
  Future<void> warmUp({required String sourceCode, required String targetCode}) async {
    try {
      await translate(text: 'a', sourceCode: sourceCode, targetCode: targetCode);
    } catch (_) {}
  }

  void dispose() {
    for (final t in _translators.values) {
      t.close();
    }
    _translators.clear();
  }
}
