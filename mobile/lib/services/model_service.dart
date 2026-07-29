import '../core/api_client.dart';
import '../core/constants.dart';
import '../models/model_config.dart';

/// Gọi API `/api/models` - kho model Vosk (STT) và ML Kit (dịch) do Admin quản lý.
class ModelService {
  final _api = ApiClient();

  Future<List<ModelConfig>> getModels({String? type, String? languageCode}) async {
    final query = <String, dynamic>{};
    if (type != null) query['type'] = type;
    if (languageCode != null) query['languageCode'] = languageCode;

    final data = await _api.get('/models', query: query.isEmpty ? null : query) as List<dynamic>;
    return data.map((e) => ModelConfig.fromJson(e as Map<String, dynamic>)).toList();
  }

  /// Lấy model ML Kit active đầu tiên cho 1 ngôn ngữ (nếu admin đã cấu hình)
  Future<ModelConfig?> getActiveMlkitModel(String languageCode) async {
    final models = await getModels(type: 'mlkit', languageCode: languageCode);
    return models.isNotEmpty ? models.first : null;
  }

  /// Lấy model Vosk active đầu tiên cho 1 ngôn ngữ (nếu admin đã cấu hình)
  Future<ModelConfig?> getActiveVoskModel(String languageCode) async {
    final models = await getModels(type: 'vosk', languageCode: languageCode);
    return models.isNotEmpty ? models.first : null;
  }

  /// Ghép domain backend (bỏ hậu tố /api) với `fileUrl` tương đối để có link tải đầy đủ.
  /// Trả về link ngoài (`downloadUrl`) nếu model không có file upload trực tiếp.
  String? getDownloadUrl(ModelConfig model) {
    if (model.hasUploadedFile) {
      final origin = AppConstants.baseUrl.replaceFirst(RegExp(r'/api/?$'), '');
      return '$origin${model.fileUrl}';
    }
    return model.downloadUrl;
  }
}
