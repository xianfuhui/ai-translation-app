import '../core/api_client.dart';
import '../models/ai_conversation.dart';

class AIService {
  final _api = ApiClient();

  /// Gửi tin nhắn, trả về (conversationId, câu trả lời của AI)
  Future<Map<String, String>> chat({String? conversationId, required String message}) async {
    final data = await _api.post('/ai/chat', body: {
      if (conversationId != null) 'conversationId': conversationId,
      'message': message,
    });
    return {'conversationId': data['conversationId'], 'reply': data['reply']};
  }

  Future<String> summarize(String conversationId) async {
    final data = await _api.post('/ai/summarize/$conversationId');
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
