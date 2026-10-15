import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'constants.dart';
import 'api_exception.dart';
import 'backend_status.dart';
import 'session.dart';

/// Client HTTP dùng chung cho toàn bộ ứng dụng.
/// Tự động đính kèm JWT token (nếu có) vào header Authorization.
class ApiClient {
  static final ApiClient _instance = ApiClient._internal();
  factory ApiClient() => _instance;
  ApiClient._internal();

  final _storage = const FlutterSecureStorage();

  /// Short on purpose: when the server is unreachable the UI must fall back to
  /// local data quickly. Slow endpoints (LLM) pass a longer [timeout].
  static const _defaultTimeout = Duration(seconds: 8);

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
    dynamic body;
    if (res.body.isNotEmpty) {
      try {
        body = jsonDecode(res.body);
      } catch (_) {
        body = null; // e.g. an HTML error page from a proxy
      }
    }
    if (res.statusCode >= 200 && res.statusCode < 300) {
      return body;
    }
    final message = body is Map && body['message'] != null
        ? body['message']
        : 'Đã có lỗi xảy ra (mã ${res.statusCode})';
    throw ApiException(message, statusCode: res.statusCode);
  }

  /// Sends one request with offline handling:
  /// - guests never call protected endpoints (fail fast as [NetworkException]);
  /// - while the backend is known to be down, fail fast instead of waiting;
  /// - socket errors / timeouts / gateway errors become [NetworkException].
  Future<dynamic> _request(
    bool auth,
    Duration? timeout,
    Future<http.Response> Function(Map<String, String> headers) send,
  ) async {
    if (auth && AppSession.isGuest) {
      throw NetworkException(
        'Bạn đang dùng chế độ khách. Đăng nhập để dùng tính năng cần máy chủ.',
        true,
      );
    }
    if (BackendStatus.isBlocked) throw NetworkException();

    final headers = await _headers(withAuth: auth);
    final http.Response res;
    try {
      res = await send(headers).timeout(timeout ?? _defaultTimeout);
    } on TimeoutException {
      BackendStatus.reportFailure();
      throw NetworkException();
    } on IOException {
      BackendStatus.reportFailure();
      throw NetworkException();
    } on http.ClientException {
      BackendStatus.reportFailure();
      throw NetworkException();
    }

    if (res.statusCode == 502 || res.statusCode == 503 || res.statusCode == 504) {
      BackendStatus.reportFailure();
      throw NetworkException();
    }
    BackendStatus.reportSuccess();
    return _handleResponse(res);
  }

  Future<dynamic> get(String path,
      {Map<String, dynamic>? query, bool auth = true, Duration? timeout}) {
    return _request(auth, timeout, (h) => http.get(_uri(path, query), headers: h));
  }

  Future<dynamic> post(String path,
      {Object? body, bool auth = true, Duration? timeout}) {
    return _request(
      auth,
      timeout,
      (h) => http.post(_uri(path), headers: h, body: jsonEncode(body ?? {})),
    );
  }

  Future<dynamic> put(String path,
      {Object? body, bool auth = true, Duration? timeout}) {
    return _request(
      auth,
      timeout,
      (h) => http.put(_uri(path), headers: h, body: jsonEncode(body ?? {})),
    );
  }

  Future<dynamic> delete(String path, {bool auth = true, Duration? timeout}) {
    return _request(auth, timeout, (h) => http.delete(_uri(path), headers: h));
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
