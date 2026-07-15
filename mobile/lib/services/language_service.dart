import '../core/api_client.dart';
import '../models/language.dart';

class LanguageService {
  final _api = ApiClient();

  Future<List<LanguageModel>> getLanguages() async {
    final data = await _api.get('/languages') as List<dynamic>;
    return data.map((e) => LanguageModel.fromJson(e as Map<String, dynamic>)).toList();
  }
}
