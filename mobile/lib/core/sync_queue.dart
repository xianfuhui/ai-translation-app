import 'api_client.dart';
import 'api_exception.dart';
import 'backend_status.dart';
import 'local_store.dart';
import 'session.dart';

/// True when a failed write should be kept and retried later (offline, server
/// error, expired token) instead of being reported as a hard failure.
bool shouldQueueOffline(Object error) {
  if (error is NetworkException) return !error.guest;
  if (error is ApiException) {
    final status = error.statusCode ?? 0;
    return status == 401 || status >= 500 || status == 408 || status == 429;
  }
  return false;
}

/// Persistent queue of writes made while the backend was unreachable.
///
/// The app is offline-first: every write lands in the local store first, then
/// is sent to the server. If that fails, an operation is queued here and
/// replayed in order by [flush] once the backend is reachable again.
///
/// Operations (all JSON maps with an `opId`):
///  - `history.create`  { localId, body }
///  - `history.delete`  { id }
///  - `history.deleteSegment` { id, at }   (at = mili-giây của lượt nói)
///  - `vocab.create`    { localId, body }   (server upserts by word+language)
///  - `vocab.delete`    { id }
///  - `vocab.flashcard` { id, value }
class SyncQueue {
  static final SyncQueue _instance = SyncQueue._();
  factory SyncQueue() => _instance;
  SyncQueue._();

  final _api = ApiClient();
  final _store = LocalStore();
  bool _flushing = false;
  int _opCounter = 0;

  static const _maxAttempts = 5;
  static const _maxIdMapEntries = 500;

  Future<void> enqueue(Map<String, dynamic> op) async {
    if (AppSession.isGuest) return; // guests have nothing to sync to
    op['opId'] = '${DateTime.now().microsecondsSinceEpoch}_${_opCounter++}';
    await _store.mutateList(LocalKeys.syncQueue, (q) => q.add(op));
  }

  Future<void> removeWhere(bool Function(Map<String, dynamic> op) test) {
    return _store.mutateList(LocalKeys.syncQueue, (q) => q.removeWhere(test));
  }

  Future<int> pendingCount() async =>
      (await _store.readList(LocalKeys.syncQueue)).length;

  /// Maps an id created offline (`local_...`) to the server id it received
  /// after syncing, so screens holding the old id keep working.
  Future<String> resolveId(String id) async {
    if (!isLocalId(id)) return id;
    final map = await _store.readMap(LocalKeys.idMap);
    final mapped = map[id];
    return mapped is String ? mapped : id;
  }

  /// Replays queued operations in order. Stops at the first operation that
  /// cannot be delivered (network down) and keeps it for next time.
  /// Returns true when the queue is empty afterwards.
  Future<bool> flush() async {
    if (AppSession.isGuest || _flushing) return false;
    _flushing = true;
    final user = AppSession.userKey;
    try {
      while (AppSession.userKey == user) {
        final queue = await _store.readList(LocalKeys.syncQueue);
        if (queue.isEmpty) return true;
        if (BackendStatus.isBlocked) return false;
        final op = queue.first;
        final handled = await _run(op);
        if (!handled) return false;
        await removeWhere((o) => o['opId'] == op['opId']);
      }
      return false;
    } finally {
      _flushing = false;
    }
  }

  /// Executes one operation. Returns true if it is finished (delivered or
  /// permanently rejected) and can leave the queue.
  Future<bool> _run(Map<String, dynamic> op) async {
    try {
      switch (op['op']) {
        case 'history.create':
          {
            final data = await _api.post('/history', body: op['body']);
            await _afterCreate(LocalKeys.history, op['localId'] as String, data);
            break;
          }
        case 'vocab.create':
          {
            final data = await _api.post('/vocabulary', body: op['body']);
            await _afterCreate(LocalKeys.vocabulary, op['localId'] as String, data);
            break;
          }
        case 'history.delete':
          await _api.delete('/history/${op['id']}');
          break;
        case 'history.deleteSegment':
          await _api.delete('/history/${op['id']}/segments?at=${op['at']}');
          break;
        case 'vocab.delete':
          await _api.delete('/vocabulary/${op['id']}');
          break;
        case 'vocab.flashcard':
          {
            final id = op['id'] as String;
            if (isLocalId(id)) return true; // its create op never produced a server id
            if (op['value'] == true) {
              await _api.put('/vocabulary/$id/flashcard');
            } else {
              await _api.delete('/vocabulary/$id/flashcard');
            }
            break;
          }
        default:
          return true; // unknown op from an older/newer app version: drop
      }
      return true;
    } on NetworkException {
      return false;
    } on ApiException catch (e) {
      final status = e.statusCode ?? 0;
      if (status == 404) return true; // already gone on the server
      if (!shouldQueueOffline(e)) return true; // permanently rejected (4xx)
      final attempts = ((op['attempts'] as num?)?.toInt() ?? 0) + 1;
      if (attempts >= _maxAttempts) return true; // poison operation: give up
      await _store.mutateList(LocalKeys.syncQueue, (q) {
        for (final o in q) {
          if (o['opId'] == op['opId']) o['attempts'] = attempts;
        }
      });
      return false;
    }
  }

  /// After a queued create succeeded: swap the local record for the server
  /// document, remember the id mapping and fix later ops that used the old id.
  Future<void> _afterCreate(String listKey, String localId, dynamic data) async {
    if (data is! Map) return;
    final server = Map<String, dynamic>.from(data);
    final serverId = server['_id'];
    await _store.mutateList(listKey, (list) {
      final i = list.indexWhere((m) => m['_id'] == localId);
      if (i != -1) list[i] = server;
    });
    if (serverId is! String) return;
    await _store.mutateMap(LocalKeys.idMap, (map) {
      map[localId] = serverId;
      while (map.length > _maxIdMapEntries) {
        map.remove(map.keys.first);
      }
    });
    await _store.mutateList(LocalKeys.syncQueue, (q) {
      for (final o in q) {
        if (o['id'] == localId) o['id'] = serverId;
      }
    });
  }

  // ===== Guest -> account migration =====

  /// When a guest logs in / registers, their local history and vocabulary move
  /// into the account (and are queued for upload) instead of being lost.
  Future<void> adoptGuestData(String userId) async {
    final guestHistoryKey = 'history_${AppSession.guestKey}';
    final guestVocabKey = 'vocab_${AppSession.guestKey}';
    final guestHistory = await _store.readList(guestHistoryKey);
    final guestVocab = await _store.readList(guestVocabKey);
    if (guestHistory.isEmpty && guestVocab.isEmpty) return;

    final userHistoryKey = 'history_$userId';
    final userVocabKey = 'vocab_$userId';
    final queueKey = 'syncq_$userId';

    // Oldest first so the account ends up with the same relative order.
    for (final h in guestHistory.reversed) {
      final id = h['_id'] as String? ?? newLocalId();
      h['_id'] = id;
      await _store.mutateList(userHistoryKey, (l) => l.insert(0, h));
      await _store.mutateList(queueKey, (q) => q.add({
            'op': 'history.create',
            'localId': id,
            'body': historyBody(h),
            'opId': '${DateTime.now().microsecondsSinceEpoch}_${_opCounter++}',
          }));
    }
    for (final v in guestVocab.reversed) {
      final id = v['_id'] as String? ?? newLocalId();
      v['_id'] = id;
      await _store.mutateList(userVocabKey, (l) {
        // Keep the account's own copy if the same word already exists.
        final exists = l.any((m) =>
            (m['word'] as String?)?.toLowerCase() ==
                (v['word'] as String?)?.toLowerCase() &&
            m['targetLanguage'] == v['targetLanguage']);
        if (!exists) l.insert(0, v);
      });
      await _store.mutateList(queueKey, (q) => q.add({
            'op': 'vocab.create',
            'localId': id,
            'body': vocabBody(v),
            'opId': '${DateTime.now().microsecondsSinceEpoch}_${_opCounter++}',
          }));
    }
    await _store.remove(guestHistoryKey);
    await _store.remove(guestVocabKey);
    await _store.remove('syncq_${AppSession.guestKey}');
  }

  /// Request body for POST /history built from a stored record.
  static Map<String, dynamic> historyBody(Map<String, dynamic> h) {
    final isConversation = h['type'] == 'conversation';
    return {
      'sourceLanguage': h['sourceLanguage'],
      'targetLanguage': h['targetLanguage'],
      'type': h['type'] ?? 'text',
      if (!isConversation) 'sourceText': h['sourceText'],
      if (!isConversation) 'translatedText': h['translatedText'],
      if (isConversation) 'segments': h['segments'],
      if (isConversation) 'startedAt': h['startedAt'],
      if (isConversation) 'endedAt': h['endedAt'],
    };
  }

  /// Request body for POST /vocabulary built from a stored record.
  static Map<String, dynamic> vocabBody(Map<String, dynamic> v) => {
        'word': v['word'],
        'meaning': v['meaning'],
        'sourceLanguage': v['sourceLanguage'],
        'targetLanguage': v['targetLanguage'],
        'source': v['source'] ?? 'manual',
      };
}
