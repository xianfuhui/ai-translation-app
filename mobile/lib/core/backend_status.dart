import 'package:flutter/foundation.dart';

/// Tracks whether the backend is reachable (a tiny circuit breaker).
///
/// After one network failure every API call fails fast for [_cooldown]
/// instead of each waiting for its own timeout, so the app stays snappy while
/// offline. A successful call (or [reset]) closes the circuit again.
class BackendStatus {
  BackendStatus._();

  /// `false` once a request failed for network reasons; UI listens to this to
  /// show the "offline" banner.
  static final ValueNotifier<bool> online = ValueNotifier<bool>(true);

  static const _cooldown = Duration(seconds: 20);
  static DateTime? _blockedUntil;

  static bool get isBlocked =>
      _blockedUntil != null && DateTime.now().isBefore(_blockedUntil!);

  static void reportFailure() {
    _blockedUntil = DateTime.now().add(_cooldown);
    online.value = false;
  }

  static void reportSuccess() {
    _blockedUntil = null;
    online.value = true;
  }

  /// Allow the next call to hit the network immediately (pull-to-refresh,
  /// "Sync now", pressing Login...).
  static void reset() {
    _blockedUntil = null;
  }
}
