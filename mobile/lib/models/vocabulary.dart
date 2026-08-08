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
    );
  }
}
