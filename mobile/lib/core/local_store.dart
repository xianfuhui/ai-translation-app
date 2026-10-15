import 'dart:async';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'session.dart';

/// Keys used by the offline layer. User-scoped keys depend on the current
/// [AppSession]; the others are shared by everyone on the device (they hold
/// public, non-personal data such as the language list).
class LocalKeys {
  LocalKeys._();

  static String get history => AppSession.scope('history');
  static String get vocabulary => AppSession.scope('vocab');
  static String get syncQueue => AppSession.scope('syncq');
  static String get idMap => AppSession.scope('idmap');

  static const languages = 'cache_languages';
  static const systemVocab = 'cache_system_vocab';
  static const systemCategories = 'cache_system_categories';
  static const installedVosk = 'installed_vosk_models';
  static const autoSpeak = 'pref_auto_speak'; // đọc to bản dịch khi ghi âm
  static const guestMode = 'guest_mode';
  static String modelConfig(String type, String lang) => 'cache_model_${type}_$lang';
}

/// Thin JSON wrapper over SharedPreferences with a lock so read-modify-write
/// updates from concurrent async callers never overwrite each other.
class LocalStore {
  static final LocalStore _instance = LocalStore._();
  factory LocalStore() => _instance;
  LocalStore._();

  Future<void> _tail = Future.value();

  Future<T> _locked<T>(Future<T> Function() action) {
    final completer = Completer<T>();
    _tail = _tail.then((_) async {
      try {
        completer.complete(await action());
      } catch (e, s) {
        completer.completeError(e, s);
      }
    });
    return completer.future;
  }

  Future<dynamic> readJson(String key) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(key);
      return raw == null ? null : jsonDecode(raw);
    } catch (_) {
      return null; // corrupted entry -> behave as "nothing cached"
    }
  }

  Future<void> writeJson(String key, Object? value) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (value == null) {
        await prefs.remove(key);
      } else {
        await prefs.setString(key, jsonEncode(value));
      }
    } catch (_) {
      // Disk full / platform error: local cache is best effort.
    }
  }

  Future<void> remove(String key) => writeJson(key, null);

  Future<List<Map<String, dynamic>>> readList(String key) async {
    final value = await readJson(key);
    if (value is! List) return [];
    return value
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  Future<Map<String, dynamic>> readMap(String key) async {
    final value = await readJson(key);
    if (value is! Map) return {};
    return Map<String, dynamic>.from(value);
  }

  Future<bool> readBool(String key) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(key) ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<void> writeBool(String key, bool value) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(key, value);
    } catch (_) {}
  }

  /// Atomic read-modify-write of a list.
  Future<void> mutateList(
    String key,
    void Function(List<Map<String, dynamic>> list) change,
  ) {
    return _locked(() async {
      final list = await readList(key);
      change(list);
      await writeJson(key, list);
    });
  }

  /// Atomic read-modify-write of a map.
  Future<void> mutateMap(
    String key,
    void Function(Map<String, dynamic> map) change,
  ) {
    return _locked(() async {
      final map = await readMap(key);
      change(map);
      await writeJson(key, map);
    });
  }
}

/// Ids of records created while offline start with this prefix; the server
/// replaces them with real ids once the record has been synced.
const _localPrefix = 'local_';
int _idCounter = 0;

String newLocalId() =>
    '$_localPrefix${DateTime.now().microsecondsSinceEpoch}_${_idCounter++}';

bool isLocalId(String? id) => id != null && id.startsWith(_localPrefix);
