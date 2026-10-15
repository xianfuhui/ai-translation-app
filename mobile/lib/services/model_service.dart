import '../core/api_client.dart';
import '../core/builtin_models.dart';
import '../core/constants.dart';
import '../core/local_store.dart';
import '../models/model_config.dart';

/// Model catalog (Vosk STT + ML Kit translation), offline-first.
///
/// Resolution order for a model config:
///  1. a model already INSTALLED on this device (Vosk) -> the backend is never
///     contacted again for that language;
///  2. the backend (result cached on success);
///  3. the cached config from an earlier successful call;
///  4. built-in defaults (Vosk only).
class ModelService {
  final _api = ApiClient();
  final _store = LocalStore();

  Future<List<ModelConfig>> getModels({String? type, String? languageCode}) async {
    final query = <String, dynamic>{};
    if (type != null) query['type'] = type;
    if (languageCode != null) query['languageCode'] = languageCode;

    final data = await _api.get('/models', query: query.isEmpty ? null : query) as List<dynamic>;
    return data.map((e) => ModelConfig.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<ModelConfig?> _readCached(String type, String languageCode) async {
    final raw = await _store.readJson(LocalKeys.modelConfig(type, languageCode));
    if (raw is! Map) return null;
    try {
      return ModelConfig.fromJson(Map<String, dynamic>.from(raw));
    } catch (_) {
      return null;
    }
  }

  /// Active model from backend (cached) or the cache. Returns null instead of
  /// throwing when the backend is unreachable and nothing was cached.
  Future<ModelConfig?> _getActiveModelWithCache(String type, String languageCode) async {
    try {
      final models = await getModels(type: type, languageCode: languageCode);
      final model = models.isNotEmpty ? models.first : null;
      if (model != null) {
        await _store.writeJson(LocalKeys.modelConfig(type, languageCode), model.toJson());
      }
      return model;
    } catch (_) {
      return _readCached(type, languageCode);
    }
  }

  /// First active ML Kit model config for a language (null = use the plain
  /// language code, which is what ML Kit expects anyway).
  Future<ModelConfig?> getActiveMlkitModel(String languageCode) {
    return _getActiveModelWithCache('mlkit', languageCode);
  }

  // ===== Vosk: installed registry =====

  Future<Map<String, dynamic>> _installedMap() => _store.readMap(LocalKeys.installedVosk);

  /// The Vosk model installed on this device for [languageCode], if any.
  Future<ModelConfig?> getInstalledVosk(String languageCode) async {
    final map = await _installedMap();
    final entry = map[languageCode];
    if (entry is! Map) return null;
    final url = entry['url'];
    if (url is! String || url.isEmpty) return null;
    return ModelConfig(
      id: 'installed_vosk_$languageCode',
      type: 'vosk',
      name: (entry['name'] as String?) ?? languageCode,
      languageCode: languageCode,
      identifier: languageCode,
      downloadUrl: url,
    );
  }

  /// Remember that the Vosk model behind [model] is on the device, so later
  /// sessions skip the backend completely.
  Future<void> markVoskInstalled(String languageCode, ModelConfig model) async {
    final url = getDownloadUrl(model);
    if (url == null || url.isEmpty) return;
    await _store.mutateMap(LocalKeys.installedVosk, (map) {
      map[languageCode] = {'name': model.name, 'url': url};
    });
  }

  Future<void> unmarkVoskInstalled(String languageCode) {
    return _store.mutateMap(LocalKeys.installedVosk, (map) => map.remove(languageCode));
  }

  /// Vosk model to use for [languageCode] (see class docs for the order).
  Future<ModelConfig?> getActiveVoskModel(String languageCode) async {
    final installed = await getInstalledVosk(languageCode);
    if (installed != null) return installed;
    final remote = await _getActiveModelWithCache('vosk', languageCode);
    return remote ?? BuiltinModels.vosk(languageCode);
  }

  /// Full download link: backend origin + `fileUrl` for files an admin
  /// uploaded, otherwise the external `downloadUrl`.
  String? getDownloadUrl(ModelConfig model) {
    if (model.hasUploadedFile) {
      final origin = AppConstants.baseUrl.replaceFirst(RegExp(r'/api/?$'), '');
      return '$origin${model.fileUrl}';
    }
    return model.downloadUrl;
  }
}
