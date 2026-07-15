class AIMessage {
  final String role; // 'user' | 'assistant'
  final String content;

  AIMessage({required this.role, required this.content});

  factory AIMessage.fromJson(Map<String, dynamic> json) {
    return AIMessage(role: json['role'] ?? 'user', content: json['content'] ?? '');
  }
}

class AIConversation {
  final String id;
  final String title;
  final String? summary;
  final List<AIMessage> messages;

  AIConversation({required this.id, required this.title, this.summary, this.messages = const []});

  factory AIConversation.fromJson(Map<String, dynamic> json) {
    return AIConversation(
      id: json['_id'] ?? '',
      title: json['title'] ?? 'Cuộc hội thoại',
      summary: json['summary'],
      messages: (json['messages'] as List<dynamic>? ?? [])
          .map((m) => AIMessage.fromJson(m as Map<String, dynamic>))
          .toList(),
    );
  }
}
