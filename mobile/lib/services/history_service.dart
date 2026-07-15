import '../core/api_client.dart';
import '../models/history.dart';

class HistoryService {
  final _api = ApiClient();

  Future<TranslationHistoryItem> createHistory({
    required String sourceLanguage,
    required String targetLanguage,
    required String sourceText,
    required String translatedText,
    String type = 'text',
  }) async {
    final data = await _api.post('/history', body: {
      'sourceLanguage': sourceLanguage,
      'targetLanguage': targetLanguage,
      'sourceText': sourceText,
      'translatedText': translatedText,
      'type': type,
    });
    return TranslationHistoryItem.fromJson(data);
  }

  Future<List<TranslationHistoryItem>> getMyHistory({int page = 1}) async {
    final data = await _api.get('/history', query: {'page': page, 'limit': 20});
    final records = data['records'] as List<dynamic>;
    return records.map((e) => TranslationHistoryItem.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<void> deleteHistory(String id) async {
    await _api.delete('/history/$id');
  }
}
