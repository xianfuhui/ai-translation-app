class VocabularyItem {
  final String id;
  final String word;
  final String? meaning;
  final String? sourceLanguage;
  final String? targetLanguage;
  final String source; // 'conversation' | 'manual'
  final bool inFlashcard;
  final String? audioUrl;

  VocabularyItem({
    required this.id,
    required this.word,
    this.meaning,
    this.sourceLanguage,
    this.targetLanguage,
    this.source = 'manual',
    this.inFlashcard = false,
    this.audioUrl,
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
    );
  }
}
