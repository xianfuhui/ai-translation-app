import '../core/api_client.dart';
import '../models/vocabulary.dart';

class VocabularyService {
  final _api = ApiClient();

  Future<VocabularyItem> saveVocabulary({
    required String word,
    String? meaning,
    String? sourceLanguage,
    String? targetLanguage,
    String source = 'manual',
  }) async {
    final data = await _api.post('/vocabulary', body: {
      'word': word,
      'meaning': meaning,
      'sourceLanguage': sourceLanguage,
      'targetLanguage': targetLanguage,
      'source': source,
    });
    return VocabularyItem.fromJson(data);
  }

  Future<List<VocabularyItem>> getMyVocabulary({bool? inFlashcard}) async {
    final data = await _api.get('/vocabulary', query: inFlashcard != null ? {'inFlashcard': inFlashcard} : null)
        as List<dynamic>;
    return data.map((e) => VocabularyItem.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<void> addToFlashcard(String id) async {
    await _api.put('/vocabulary/$id/flashcard');
  }

  Future<void> deleteVocabulary(String id) async {
    await _api.delete('/vocabulary/$id');
  }

  Future<List<VocabularyItem>> getSystemVocabulary({String? search}) async {
    final data = await _api.get('/vocabulary/system', query: search != null ? {'search': search} : null)
        as List<dynamic>;
    return data.map((e) => VocabularyItem.fromJson(e as Map<String, dynamic>)).toList();
  }
}
