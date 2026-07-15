import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'constants.dart';
import 'api_exception.dart';

/// Client HTTP dùng chung cho toàn bộ ứng dụng.
/// Tự động đính kèm JWT token (nếu có) vào header Authorization.
class ApiClient {
  static final ApiClient _instance = ApiClient._internal();
  factory ApiClient() => _instance;
  ApiClient._internal();

  final _storage = const FlutterSecureStorage();

  Future<String?> get token async => _storage.read(key: AppConstants.tokenKey);

  Future<Map<String, String>> _headers({bool withAuth = true}) async {
    final headers = {'Content-Type': 'application/json'};
    if (withAuth) {
      final t = await token;
      if (t != null) headers['Authorization'] = 'Bearer $t';
    }
    return headers;
  }

  Uri _uri(String path, [Map<String, dynamic>? query]) {
    final normalized = path.startsWith('/') ? path : '/$path';
    return Uri.parse('${AppConstants.baseUrl}$normalized').replace(
      queryParameters: query?.map((k, v) => MapEntry(k, v.toString())),
    );
  }

  dynamic _handleResponse(http.Response res) {
    final body = res.body.isNotEmpty ? jsonDecode(res.body) : null;
    if (res.statusCode >= 200 && res.statusCode < 300) {
      return body;
    }
    final message = body is Map && body['message'] != null
        ? body['message']
        : 'Đã có lỗi xảy ra (mã ${res.statusCode})';
    throw ApiException(message, statusCode: res.statusCode);
  }

  Future<dynamic> get(String path, {Map<String, dynamic>? query, bool auth = true}) async {
    final res = await http.get(_uri(path, query), headers: await _headers(withAuth: auth));
    return _handleResponse(res);
  }

  Future<dynamic> post(String path, {Object? body, bool auth = true}) async {
    final res = await http.post(_uri(path), headers: await _headers(withAuth: auth), body: jsonEncode(body ?? {}));
    return _handleResponse(res);
  }

  Future<dynamic> put(String path, {Object? body, bool auth = true}) async {
    final res = await http.put(_uri(path), headers: await _headers(withAuth: auth), body: jsonEncode(body ?? {}));
    return _handleResponse(res);
  }

  Future<dynamic> delete(String path, {bool auth = true}) async {
    final res = await http.delete(_uri(path), headers: await _headers(withAuth: auth));
    return _handleResponse(res);
  }

  Future<void> saveSession(String token, Map<String, dynamic> user) async {
    await _storage.write(key: AppConstants.tokenKey, value: token);
    await _storage.write(key: AppConstants.userKey, value: jsonEncode(user));
  }

  Future<Map<String, dynamic>?> getSavedUser() async {
    final raw = await _storage.read(key: AppConstants.userKey);
    if (raw == null) return null;
    return jsonDecode(raw) as Map<String, dynamic>;
  }

  Future<void> clearSession() async {
    await _storage.delete(key: AppConstants.tokenKey);
    await _storage.delete(key: AppConstants.userKey);
  }
}
