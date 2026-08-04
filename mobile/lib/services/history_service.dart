import '../core/api_client.dart';
import '../models/history.dart';

class HistoryService {
  final _api = ApiClient();

  Future<TranslationHistoryItem> createHistory({
    required String sourceLanguage,
    required String targetLanguage,
    String? sourceText,
    String? translatedText,
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

  /// Lưu 1 phiên dịch trực tiếp (Bắt đầu -> Dừng) thành 1 mục lịch sử duy nhất,
  /// gộp toàn bộ các lượt nói trong phiên đó vào `segments`, kèm giờ Bắt đầu/Dừng.
  Future<TranslationHistoryItem> createConversationHistory({
    required String sourceLanguage,
    required String targetLanguage,
    required List<HistorySegment> segments,
    required DateTime startedAt,
    required DateTime endedAt,
  }) async {
    final data = await _api.post('/history', body: {
      'sourceLanguage': sourceLanguage,
      'targetLanguage': targetLanguage,
      'type': 'conversation',
      'segments': segments.map((s) => s.toJson()).toList(),
      'startedAt': startedAt.toIso8601String(),
      'endedAt': endedAt.toIso8601String(),
    });
    return TranslationHistoryItem.fromJson(data);
  }

  Future<List<TranslationHistoryItem>> getMyHistory({int page = 1}) async {
    final data = await _api.get('/history', query: {'page': page, 'limit': 20});
    final records = data['records'] as List<dynamic>;
    return records.map((e) => TranslationHistoryItem.fromJson(e as Map<String, dynamic>)).toList();
  }

  /// Bấm nút LLM trên 1 mục lịch sử để tóm tắt nội dung (backend tự cắt bớt
  /// nếu vượt giới hạn ký tự cho phép gửi tới LLM).
  Future<String> summarizeHistory(String id) async {
    final data = await _api.post('/history/$id/summarize');
    return data['summary'] as String? ?? '';
  }

  Future<void> deleteHistory(String id) async {
    await _api.delete('/history/$id');
  }
}
