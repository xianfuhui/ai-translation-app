import 'package:flutter/foundation.dart';
import '../core/api_client.dart';
import '../core/api_exception.dart';
import '../core/local_store.dart';
import '../core/session.dart';
import '../core/sync_queue.dart';
import '../models/history.dart';

/// Translation history, local-first.
///
/// Every record is written to the device first, so history works for guests
/// and without a connection. Signed-in users additionally push to the backend;
/// failed pushes are queued (see [SyncQueue]) and retried later.
class HistoryService {
  static const _maxLocal = 200;

  /// Tăng mỗi khi lịch sử trên máy đổi (thêm / xóa / có tóm tắt) — tab Lịch sử
  /// nghe cái này để tự cập nhật.
  static final ValueNotifier<int> changes = ValueNotifier<int>(0);

  final _api = ApiClient();
  final _store = LocalStore();
  final _sync = SyncQueue();

  Future<TranslationHistoryItem> createHistory({
    required String sourceLanguage,
    required String targetLanguage,
    String? sourceText,
    String? translatedText,
    String type = 'text',
  }) {
    final local = TranslationHistoryItem(
      id: newLocalId(),
      sourceLanguage: sourceLanguage,
      targetLanguage: targetLanguage,
      sourceText: sourceText ?? '',
      translatedText: translatedText ?? '',
      type: type,
      createdAt: DateTime.now(),
    );
    return _create(local, {
      'sourceLanguage': sourceLanguage,
      'targetLanguage': targetLanguage,
      'sourceText': sourceText,
      'translatedText': translatedText,
      'type': type,
    });
  }

  /// Saves one live-translate session (Start -> Stop) as ONE history entry
  /// holding all spoken turns in `segments`.
  Future<TranslationHistoryItem> createConversationHistory({
    required String sourceLanguage,
    required String targetLanguage,
    required List<HistorySegment> segments,
    required DateTime startedAt,
    required DateTime endedAt,
  }) {
    final local = TranslationHistoryItem(
      id: newLocalId(),
      sourceLanguage: sourceLanguage,
      targetLanguage: targetLanguage,
      sourceText: '',
      translatedText: '',
      type: 'conversation',
      segments: segments,
      startedAt: startedAt,
      endedAt: endedAt,
      createdAt: DateTime.now(),
    );
    return _create(local, {
      'sourceLanguage': sourceLanguage,
      'targetLanguage': targetLanguage,
      'type': 'conversation',
      'segments': segments.map((s) => s.toJson()).toList(),
      'startedAt': startedAt.toUtc().toIso8601String(),
      'endedAt': endedAt.toUtc().toIso8601String(),
    });
  }

  Future<TranslationHistoryItem> _create(
    TranslationHistoryItem local,
    Map<String, dynamic> body,
  ) async {
    await _store.mutateList(LocalKeys.history, (list) {
      list.insert(0, local.toJson());
      if (list.length > _maxLocal) list.removeRange(_maxLocal, list.length);
    });
    changes.value++;
    if (AppSession.isGuest) return local;

    try {
      final data = await _api.post('/history', body: body);
      final server = TranslationHistoryItem.fromJson(data as Map<String, dynamic>);
      await _store.mutateList(LocalKeys.history, (list) {
        final i = list.indexWhere((m) => m['_id'] == local.id);
        if (i != -1) list[i] = server.toJson();
      });
      changes.value++;
      return server;
    } catch (e) {
      if (shouldQueueOffline(e)) {
        await _sync.enqueue({'op': 'history.create', 'localId': local.id, 'body': body});
      }
      return local; // the record is safe on the device either way
    }
  }

  /// Records stored on this device (instant, works offline).
  Future<List<TranslationHistoryItem>> getCachedHistory() async {
    final list = await _store.readList(LocalKeys.history);
    return list.map(TranslationHistoryItem.fromJson).toList();
  }

  /// Syncs with the backend when possible, then returns the local history.
  Future<List<TranslationHistoryItem>> getMyHistory({int page = 1}) async {
    if (!AppSession.isGuest && page == 1) {
      try {
        await _sync.flush();
        final data = await _api.get('/history', query: {'page': 1, 'limit': 50});
        final records = (data['records'] as List<dynamic>)
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();
        await _store.mutateList(LocalKeys.history, (list) {
          // Keep records that were not uploaded yet, take the rest from the server.
          final pending = list.where((m) => isLocalId(m['_id'] as String?)).toList();
          final merged = [...pending, ...records];
          merged.sort((a, b) => _time(b).compareTo(_time(a)));
          list
            ..clear()
            ..addAll(merged.take(_maxLocal));
        });
      } catch (_) {
        // offline: the local copy below is what the user sees
      }
    }
    return getCachedHistory();
  }

  DateTime _time(Map<String, dynamic> m) =>
      DateTime.tryParse('${m['createdAt']}') ?? DateTime.fromMillisecondsSinceEpoch(0);

  /// AI summary needs the LLM on the backend: online + signed-in only.
  Future<String> summarizeHistory(String id) async {
    final realId = await _sync.resolveId(id);
    if (isLocalId(realId) && !AppSession.isGuest) {
      throw ApiException('Mục này chưa được đồng bộ. Hãy kết nối mạng rồi thử lại.');
    }
    final data = await _api.post(
      '/history/$realId/summarize',
      timeout: const Duration(seconds: 60),
    );
    final summary = data['summary'] as String? ?? '';
    // Keep the summary on the device so it can be read offline later.
    await _store.mutateList(LocalKeys.history, (list) {
      for (final m in list) {
        if (m['_id'] == realId) m['summary'] = summary;
      }
    });
    changes.value++;
    return summary;
  }

  /// Deletes locally right away; the server delete is queued if it cannot be
  /// delivered now.
  Future<void> deleteHistory(String id) async {
    final realId = await _sync.resolveId(id);
    await _store.mutateList(
      LocalKeys.history,
      (list) => list.removeWhere((m) => m['_id'] == realId || m['_id'] == id),
    );
    changes.value++;
    if (isLocalId(realId)) {
      // Never reached the server: just cancel its upload.
      await _sync.removeWhere((op) => op['op'] == 'history.create' && op['localId'] == realId);
      return;
    }
    if (AppSession.isGuest) return;
    try {
      await _api.delete('/history/$realId');
    } catch (e) {
      if (shouldQueueOffline(e)) {
        await _sync.enqueue({'op': 'history.delete', 'id': realId});
      }
    }
  }

  /// Xóa 1 lượt nói khỏi phiên hội thoại [id]. Xóa trên máy ngay; gửi lên máy chủ
  /// khi có mạng. Trả về true nếu đó là lượt cuối nên cả phiên bị xóa theo.
  Future<bool> deleteSegment(String id, DateTime at) async {
    final realId = await _sync.resolveId(id);
    final ms = at.millisecondsSinceEpoch;
    bool sameSegment(dynamic m) {
      final t = DateTime.tryParse('${(m as Map)['at']}');
      return t != null && t.millisecondsSinceEpoch == ms;
    }

    var wholeDeleted = false;
    await _store.mutateList(LocalKeys.history, (list) {
      for (final m in list) {
        if (m['_id'] != realId && m['_id'] != id) continue;
        final segs = m['segments'];
        if (segs is List) segs.removeWhere(sameSegment);
        if (segs is List && segs.isEmpty) wholeDeleted = true;
      }
      if (wholeDeleted) {
        list.removeWhere((m) => m['_id'] == realId || m['_id'] == id);
      }
    });
    changes.value++;

    if (isLocalId(realId)) {
      // Chưa lên máy chủ: sửa luôn bản "tạo mới" đang chờ gửi (hoặc huỷ nó).
      if (wholeDeleted) {
        await _sync.removeWhere((op) => op['op'] == 'history.create' && op['localId'] == realId);
      } else {
        await _store.mutateList(LocalKeys.syncQueue, (q) {
          for (final op in q) {
            if (op['op'] == 'history.create' && op['localId'] == realId) {
              final body = op['body'];
              final segs = body is Map ? body['segments'] : null;
              if (segs is List) segs.removeWhere(sameSegment);
            }
          }
        });
      }
      return wholeDeleted;
    }
    if (AppSession.isGuest) return wholeDeleted;
    try {
      await _api.delete('/history/$realId/segments?at=$ms');
    } catch (e) {
      if (shouldQueueOffline(e)) {
        await _sync.enqueue({'op': 'history.deleteSegment', 'id': realId, 'at': ms});
      }
    }
    return wholeDeleted;
  }
}
