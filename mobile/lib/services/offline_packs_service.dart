import '../models/language.dart';
import 'language_service.dart';
import 'model_service.dart';
import 'translation_service.dart';
import 'vosk_service.dart';

/// Các gói ngoại tuyến đang nằm trên máy (để hiện ở màn Cá nhân).
class DownloadedPacks {
  final List<String> translation; // tên ngôn ngữ đã tải gói dịch (ML Kit)
  final List<String> speech; // tên ngôn ngữ đã tải gói giọng nói (Vosk)

  const DownloadedPacks({this.translation = const [], this.speech = const []});

  bool get isEmpty => translation.isEmpty && speech.isEmpty;

  /// Dòng mô tả ngắn: liệt kê các model đã tải, không có thì ghi "Không".
  String get summary {
    if (isEmpty) return 'Không';
    final parts = <String>[];
    if (translation.isNotEmpty) parts.add('Dịch: ${translation.join(', ')}');
    if (speech.isNotEmpty) parts.add('Giọng nói: ${speech.join(', ')}');
    return parts.join('\n');
  }
}

class OfflinePacksService {
  final _languages = LanguageService();
  final _translation = TranslationService();
  final _models = ModelService();
  final _vosk = VoskService();

  Future<DownloadedPacks> getDownloaded() async {
    final langs = await _languages.getLanguages();
    final translation = <String>[];
    final speech = <String>[];

    for (final LanguageModel lang in langs) {
      try {
        if (_translation.isSupported(lang.code) &&
            await _translation.isModelDownloaded(lang.code)) {
          translation.add(lang.name);
        }
      } catch (_) {}
      try {
        if (VoskService.isSupported) {
          final config = await _models.getActiveVoskModel(lang.code);
          final url = config == null ? null : _models.getDownloadUrl(config);
          if (url != null && await _vosk.isModelDownloaded(url)) {
            speech.add(lang.name);
          }
        }
      } catch (_) {}
    }
    _translation.dispose();
    return DownloadedPacks(translation: translation, speech: speech);
  }
}
