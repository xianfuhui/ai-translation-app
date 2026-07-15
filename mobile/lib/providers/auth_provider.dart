import 'package:flutter/foundation.dart';
import '../models/user.dart';
import '../services/auth_service.dart';

enum AuthStatus { unknown, authenticated, unauthenticated }

class AuthProvider extends ChangeNotifier {
  final _authService = AuthService();

  AuthStatus status = AuthStatus.unknown;
  AppUser? currentUser;
  String? errorMessage;
  bool isLoading = false;

  Future<void> tryRestoreSession() async {
    final user = await _authService.restoreSession();
    currentUser = user;
    status = user != null ? AuthStatus.authenticated : AuthStatus.unauthenticated;
    notifyListeners();
  }

  Future<bool> login(String email, String password) => _run(() async {
        currentUser = await _authService.login(email: email, password: password);
        status = AuthStatus.authenticated;
      });

  Future<bool> register(String fullName, String email, String password) => _run(() async {
        currentUser = await _authService.register(fullName: fullName, email: email, password: password);
        status = AuthStatus.authenticated;
      });

  Future<bool> changePassword(String oldPassword, String newPassword) => _run(() async {
        await _authService.changePassword(oldPassword: oldPassword, newPassword: newPassword);
      });

  Future<void> logout() async {
    await _authService.logout();
    currentUser = null;
    status = AuthStatus.unauthenticated;
    notifyListeners();
  }

  /// Chạy 1 thao tác async, tự quản lý isLoading/errorMessage, trả về true nếu thành công
  Future<bool> _run(Future<void> Function() action) async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();
    try {
      await action();
      isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      isLoading = false;
      errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }
}
