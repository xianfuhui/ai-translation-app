import '../core/api_client.dart';
import '../models/ai_conversation.dart';

/// AI assistant (Gemini through the backend). This is the one feature that
/// cannot work offline or as a guest; callers show a friendly message when a
/// [NetworkException] is thrown.
class AIService {
  final _api = ApiClient();

  /// LLM calls can take a while; the default 8s API timeout would cut them.
  static const _llmTimeout = Duration(seconds: 60);

  /// Gửi tin nhắn, trả về (conversationId, câu trả lời của AI)
  Future<Map<String, String>> chat({String? conversationId, required String message}) async {
    final data = await _api.post('/ai/chat', body: {
      if (conversationId != null) 'conversationId': conversationId,
      'message': message,
    }, timeout: _llmTimeout);
    return {'conversationId': data['conversationId'], 'reply': data['reply']};
  }

  Future<String> summarize(String conversationId) async {
    final data = await _api.post('/ai/summarize/$conversationId', timeout: _llmTimeout);
    return data['summary'] as String;
  }

  Future<List<AIConversation>> getConversations() async {
    final data = await _api.get('/ai/conversations') as List<dynamic>;
    return data.map((e) => AIConversation.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<AIConversation> getConversationById(String id) async {
    final data = await _api.get('/ai/conversations/$id');
    return AIConversation.fromJson(data);
  }
}
