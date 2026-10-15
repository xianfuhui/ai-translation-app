import '../core/api_client.dart';
import '../core/api_exception.dart';
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

  /// Restores the saved session. A missing network must NOT log the user out:
  /// when the server cannot be reached, the saved profile is trusted and the app
  /// opens offline. Only an explicit 401/403 clears the session.
  Future<AppUser?> restoreSession() async {
    final token = await _api.token;
    if (token == null) return null;
    try {
      final data = await _api.get('/auth/me');
      final user = AppUser.fromJson(data);
      await _api.saveSession(token, user.toJson()); // refresh the offline copy
      return user;
    } on NetworkException {
      return _savedUserOrNull();
    } on ApiException catch (e) {
      if (e.statusCode == 401 || e.statusCode == 403) {
        await _api.clearSession();
        return null;
      }
      return _savedUserOrNull(); // server error: keep working offline
    } catch (_) {
      return _savedUserOrNull();
    }
  }

  Future<AppUser?> _savedUserOrNull() async {
    final saved = await _api.getSavedUser();
    if (saved == null) {
      await _api.clearSession();
      return null;
    }
    return AppUser.fromJson(saved);
  }
}
