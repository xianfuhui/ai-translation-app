import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../core/api_client.dart';
import '../core/constants.dart';
import '../models/model_config.dart';

/// Gọi API `/api/models` - kho model Vosk (STT) và ML Kit (dịch) do Admin quản lý.
///
/// Mỗi lần lấy được config model "active" cho 1 ngôn ngữ thành công từ backend,
/// kết quả được cache lại xuống máy (`flutter_secure_storage`). Lần sau nếu
/// backend không gọi được (mất mạng, tắt backend...), tự động dùng lại config
/// đã cache thay vì báo lỗi ngay - miễn là model tương ứng đã từng tải về máy.
class ModelService {
  final _api = ApiClient();
  final _cache = const FlutterSecureStorage();

  String _cacheKey(String type, String languageCode) => 'model_cache_${type}_$languageCode';

  Future<void> _saveToCache(String type, String languageCode, ModelConfig model) async {
    await _cache.write(key: _cacheKey(type, languageCode), value: jsonEncode(model.toJson()));
  }

  Future<ModelConfig?> _readFromCache(String type, String languageCode) async {
    final raw = await _cache.read(key: _cacheKey(type, languageCode));
    if (raw == null) return null;
    try {
      return ModelConfig.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null; // Cache hỏng/không đọc được -> coi như chưa có cache
    }
  }

  Future<List<ModelConfig>> getModels({String? type, String? languageCode}) async {
    final query = <String, dynamic>{};
    if (type != null) query['type'] = type;
    if (languageCode != null) query['languageCode'] = languageCode;

    final data = await _api.get('/models', query: query.isEmpty ? null : query) as List<dynamic>;
    return data.map((e) => ModelConfig.fromJson(e as Map<String, dynamic>)).toList();
  }

  /// Lấy 1 model "active" cho 1 ngôn ngữ + type, có cache/fallback offline.
  /// - Gọi backend thành công -> lưu cache rồi trả về.
  /// - Gọi backend lỗi (mất mạng, tắt backend...) -> dùng lại cache lần gần
  ///   nhất nếu có; không có cache thì mới ném lỗi ra ngoài.
  Future<ModelConfig?> _getActiveModelWithCache(String type, String languageCode) async {
    try {
      final models = await getModels(type: type, languageCode: languageCode);
      final model = models.isNotEmpty ? models.first : null;
      if (model != null) await _saveToCache(type, languageCode, model);
      return model;
    } catch (e) {
      final cached = await _readFromCache(type, languageCode);
      if (cached != null) return cached;
      rethrow; // Chưa từng lấy được config này lần nào -> bắt buộc phải có backend
    }
  }

  /// Lấy model ML Kit active đầu tiên cho 1 ngôn ngữ (nếu admin đã cấu hình)
  Future<ModelConfig?> getActiveMlkitModel(String languageCode) {
    return _getActiveModelWithCache('mlkit', languageCode);
  }

  /// Lấy model Vosk active đầu tiên cho 1 ngôn ngữ (nếu admin đã cấu hình)
  Future<ModelConfig?> getActiveVoskModel(String languageCode) {
    return _getActiveModelWithCache('vosk', languageCode);
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
