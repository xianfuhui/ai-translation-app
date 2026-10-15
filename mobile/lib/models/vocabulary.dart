class VocabularyItem {
  final String id;
  final String word;
  final String? meaning;
  final String? sourceLanguage;
  final String? targetLanguage;
  final String source; // 'conversation' | 'manual'
  final bool inFlashcard;
  final String? audioUrl;
  final String? phonetic; // phiên âm (dấu phát âm), vd: /wɜːrd/
  // Chỉ có ý nghĩa với từ trong Kho hệ thống: từ này đã có trong sổ tay của tôi chưa
  final bool inMyVocabulary;
  // Thời điểm lưu (Mongoose timestamps) — UI v2 dùng để gắn nhãn "mới lưu".
  final DateTime? createdAt;
  // Topic of a system-vocabulary word (used to filter the cached bank offline).
  final String? category;

  VocabularyItem({
    required this.id,
    required this.word,
    this.meaning,
    this.sourceLanguage,
    this.targetLanguage,
    this.source = 'manual',
    this.inFlashcard = false,
    this.audioUrl,
    this.phonetic,
    this.inMyVocabulary = false,
    this.createdAt,
    this.category,
  });

  factory VocabularyItem.fromJson(Map<String, dynamic> json) {
    return VocabularyItem(
      id: json['_id'] ?? '',
      word: json['word'] ?? '',
      meaning: json['meaning'],
      sourceLanguage: json['sourceLanguage'],
      targetLanguage: json['targetLanguage'],
      source: json['source'] ?? 'manual',
      inFlashcard: json['inFlashcard'] ?? false,
      audioUrl: json['audioUrl'],
      phonetic: json['phonetic'],
      inMyVocabulary: json['inMyVocabulary'] ?? false,
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'] as String)
          : null,
      category: json['category'] as String?,
    );
  }

  /// Local cache format (same field names as the server documents).
  Map<String, dynamic> toJson() => {
        '_id': id,
        'word': word,
        'meaning': meaning,
        'sourceLanguage': sourceLanguage,
        'targetLanguage': targetLanguage,
        'source': source,
        'inFlashcard': inFlashcard,
        'audioUrl': audioUrl,
        'phonetic': phonetic,
        'inMyVocabulary': inMyVocabulary,
        'createdAt': createdAt?.toUtc().toIso8601String(),
        'category': category,
      };
}
