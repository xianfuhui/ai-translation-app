import '../core/api_client.dart';
import '../core/builtin_models.dart';
import '../core/local_store.dart';
import '../models/language.dart';

/// Supported languages, offline-first: backend -> last cached list -> built-in
/// defaults. Never throws, so the translate screen always has languages.
class LanguageService {
  final _api = ApiClient();
  final _store = LocalStore();

  Future<List<LanguageModel>> getLanguages() async {
    try {
      final data = await _api.get('/languages') as List<dynamic>;
      final langs = data
          .map((e) => LanguageModel.fromJson(e as Map<String, dynamic>))
          .where((l) => l.code.isNotEmpty)
          .toList();
      if (langs.isNotEmpty) {
        await _store.writeJson(
          LocalKeys.languages,
          langs.map((l) => l.toJson()).toList(),
        );
        return langs;
      }
    } catch (_) {
      // offline / guest / server error: fall through to local data
    }
    final cached = await _store.readList(LocalKeys.languages);
    if (cached.isNotEmpty) {
      return cached.map(LanguageModel.fromJson).toList();
    }
    return BuiltinModels.languages();
  }
}
