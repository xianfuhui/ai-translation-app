import '../core/api_client.dart';
import '../models/user.dart';

class AuthService {
  final _api = ApiClient();

  Future<AppUser> register({required String fullName, required String email, required String password}) async {
    final data = await _api.post('/auth/register', body: {
      'fullName': fullName,
      'email': email,
      'password': password,
    }, auth: false);

    final user = AppUser.fromJson(data['user']);
    await _api.saveSession(data['token'], user.toJson());
    return user;
  }

  Future<AppUser> login({required String email, required String password}) async {
    final data = await _api.post('/auth/login', body: {'email': email, 'password': password}, auth: false);
    final user = AppUser.fromJson(data['user']);
    await _api.saveSession(data['token'], user.toJson());
    return user;
  }

  Future<void> logout() async {
    try {
      await _api.post('/auth/logout');
    } catch (_) {
      // Vẫn xóa session cục bộ dù gọi API logout thất bại (vd: mất mạng)
    }
    await _api.clearSession();
  }

  Future<void> changePassword({required String oldPassword, required String newPassword}) async {
    await _api.put('/auth/change-password', body: {'oldPassword': oldPassword, 'newPassword': newPassword});
  }

  Future<AppUser?> restoreSession() async {
    final token = await _api.token;
    if (token == null) return null;
    try {
      final data = await _api.get('/auth/me');
      return AppUser.fromJson(data);
    } catch (_) {
      await _api.clearSession();
      return null;
    }
  }
}
