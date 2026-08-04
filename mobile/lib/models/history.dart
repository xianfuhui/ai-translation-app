class HistorySegment {
  final String sourceText;
  final String translatedText;
  final DateTime at;

  HistorySegment({required this.sourceText, required this.translatedText, DateTime? at}) : at = at ?? DateTime.now();

  factory HistorySegment.fromJson(Map<String, dynamic> json) => HistorySegment(
        sourceText: json['sourceText'] ?? '',
        translatedText: json['translatedText'] ?? '',
        at: DateTime.tryParse(json['at'] ?? ''),
      );

  Map<String, dynamic> toJson() => {
        'sourceText': sourceText,
        'translatedText': translatedText,
        'at': at.toIso8601String(),
      };
}

class TranslationHistoryItem {
  final String id;
  final String sourceLanguage;
  final String targetLanguage;
  final String sourceText;
  final String translatedText;
  final String type;
  // Chỉ có giá trị với type 'conversation': toàn bộ các lượt nói trong 1 phiên
  // dịch trực tiếp Bắt đầu/Dừng.
  final List<HistorySegment> segments;
  // Giờ bấm Bắt đầu / Dừng của phiên (chỉ có với type 'conversation')
  final DateTime? startedAt;
  final DateTime? endedAt;
  // Bản tóm tắt do LLM tạo ra (nếu người dùng đã bấm nút tóm tắt)
  final String? summary;
  final DateTime createdAt;

  bool get isConversation => type == 'conversation';

  TranslationHistoryItem({
    required this.id,
    required this.sourceLanguage,
    required this.targetLanguage,
    required this.sourceText,
    required this.translatedText,
    required this.type,
    this.segments = const [],
    this.startedAt,
    this.endedAt,
    this.summary,
    required this.createdAt,
  });

  factory TranslationHistoryItem.fromJson(Map<String, dynamic> json) {
    return TranslationHistoryItem(
      id: json['_id'] ?? '',
      sourceLanguage: json['sourceLanguage'] ?? '',
      targetLanguage: json['targetLanguage'] ?? '',
      sourceText: json['sourceText'] ?? '',
      translatedText: json['translatedText'] ?? '',
      type: json['type'] ?? 'text',
      segments: (json['segments'] as List<dynamic>?)
              ?.map((e) => HistorySegment.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      startedAt: json['startedAt'] != null ? DateTime.tryParse(json['startedAt']) : null,
      endedAt: json['endedAt'] != null ? DateTime.tryParse(json['endedAt']) : null,
      summary: json['summary'],
      createdAt: DateTime.tryParse(json['createdAt'] ?? '') ?? DateTime.now(),
    );
  }
}
