import 'dart:async';
import 'package:flutter/foundation.dart';
import '../core/backend_status.dart';
import '../core/local_store.dart';
import '../core/session.dart';
import '../core/sync_queue.dart';
import '../models/user.dart';
import '../services/auth_service.dart';

/// `guest` = using the app without an account: everything is stored on this
/// device only and server-only features (AI chat, system word bank refresh,
/// password change) are unavailable.
enum AuthStatus { unknown, authenticated, guest, unauthenticated }

class AuthProvider extends ChangeNotifier {
  final _authService = AuthService();
  final _store = LocalStore();

  AuthStatus status = AuthStatus.unknown;
  AppUser? currentUser;
  String? errorMessage;
  bool isLoading = false;

  bool get isGuest => status == AuthStatus.guest;
  bool get isSignedIn => status == AuthStatus.authenticated;

  /// Runs at app start. Works without a connection: a saved account opens
  /// offline, otherwise a previous guest session is resumed.
  Future<void> tryRestoreSession() async {
    AppSession.clear();
    final user = await _authService.restoreSession();
    if (user != null) {
      AppSession.setUser(user.id);
      currentUser = user;
      status = AuthStatus.authenticated;
      unawaited(SyncQueue().flush()); // push anything written while offline
    } else if (await _store.readBool(LocalKeys.guestMode)) {
      _enterGuest();
    } else {
      currentUser = null;
      status = AuthStatus.unauthenticated;
    }
    notifyListeners();
  }

  /// "Use as guest": no account, no backend.
  Future<void> continueAsGuest() async {
    await _store.writeBool(LocalKeys.guestMode, true);
    _enterGuest();
    errorMessage = null;
    notifyListeners();
  }

  void _enterGuest() {
    AppSession.setGuest();
    currentUser = AppUser(
      id: AppSession.guestKey,
      fullName: 'Khách',
      email: '',
      role: 'guest',
    );
    status = AuthStatus.guest;
  }

  Future<bool> login(String email, String password) => _run(() async {
        final wasGuest = isGuest;
        BackendStatus.reset();
        final user = await _authService.login(email: email, password: password);
        await _signedIn(user, wasGuest);
      });

  Future<bool> register(String fullName, String email, String password) => _run(() async {
        final wasGuest = isGuest;
        BackendStatus.reset();
        final user = await _authService.register(
          fullName: fullName,
          email: email,
          password: password,
        );
        await _signedIn(user, wasGuest);
      });

  /// Common tail of login/register. A guest's local data moves into the
  /// account and is uploaded in the background.
  Future<void> _signedIn(AppUser user, bool wasGuest) async {
    if (wasGuest) await SyncQueue().adoptGuestData(user.id);
    await _store.writeBool(LocalKeys.guestMode, false);
    AppSession.setUser(user.id);
    currentUser = user;
    status = AuthStatus.authenticated;
    unawaited(SyncQueue().flush());
  }

  Future<bool> changePassword(String oldPassword, String newPassword) => _run(() async {
        await _authService.changePassword(oldPassword: oldPassword, newPassword: newPassword);
      });

  Future<void> logout() async {
    if (isGuest) {
      await _store.writeBool(LocalKeys.guestMode, false);
    } else {
      try {
        await SyncQueue().flush(); // best effort: upload pending changes first
      } catch (_) {}
      await _authService.logout();
    }
    AppSession.clear();
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
