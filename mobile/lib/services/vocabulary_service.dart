import '../core/api_client.dart';
import '../core/local_store.dart';
import '../core/session.dart';
import '../core/sync_queue.dart';
import '../models/vocabulary.dart';

/// Personal vocabulary (notebook + flashcards), local-first, plus the
/// read-only system word bank which is cached for offline browsing.
class VocabularyService {
  final _api = ApiClient();
  final _store = LocalStore();
  final _sync = SyncQueue();

  // ===== My vocabulary =====

  Future<VocabularyItem> saveVocabulary({
    required String word,
    required String meaning,
    String? sourceLanguage,
    String? targetLanguage,
    String source = 'manual',
  }) async {
    final cleanWord = word.trim();
    late VocabularyItem local;
    await _store.mutateList(LocalKeys.vocabulary, (list) {
      // Same word + target language is the same entry (matches the server's
      // upsert), so saving again just updates the meaning.
      final i = list.indexWhere((m) =>
          (m['word'] as String?)?.toLowerCase() == cleanWord.toLowerCase() &&
          m['targetLanguage'] == targetLanguage);
      if (i != -1) {
        list[i]['meaning'] = meaning;
        list[i]['sourceLanguage'] = sourceLanguage;
        local = VocabularyItem.fromJson(list[i]);
      } else {
        local = VocabularyItem(
          id: newLocalId(),
          word: cleanWord,
          meaning: meaning,
          sourceLanguage: sourceLanguage,
          targetLanguage: targetLanguage,
          source: source,
          createdAt: DateTime.now(),
        );
        list.insert(0, local.toJson());
      }
    });
    if (AppSession.isGuest) return local;

    final body = {
      'word': cleanWord,
      'meaning': meaning,
      'sourceLanguage': sourceLanguage,
      'targetLanguage': targetLanguage,
      'source': source,
    };
    try {
      final data = await _api.post('/vocabulary', body: body);
      final server = VocabularyItem.fromJson(data as Map<String, dynamic>);
      await _store.mutateList(LocalKeys.vocabulary, (list) {
        final i = list.indexWhere((m) => m['_id'] == local.id);
        if (i != -1) list[i] = server.toJson();
      });
      return server;
    } catch (e) {
      if (shouldQueueOffline(e)) {
        await _sync.enqueue({'op': 'vocab.create', 'localId': local.id, 'body': body});
      }
      return local;
    }
  }

  /// Words stored on this device (instant, works offline).
  Future<List<VocabularyItem>> getCachedVocabulary({bool? inFlashcard}) async {
    final list = await _store.readList(LocalKeys.vocabulary);
    final items = list.map(VocabularyItem.fromJson).toList();
    if (inFlashcard == null) return items;
    return items.where((v) => v.inFlashcard == inFlashcard).toList();
  }

  /// Syncs with the backend when possible, then returns the local words.
  Future<List<VocabularyItem>> getMyVocabulary({bool? inFlashcard}) async {
    if (!AppSession.isGuest) {
      try {
        await _sync.flush();
        final data = await _api.get('/vocabulary') as List<dynamic>;
        final records = data.map((e) => Map<String, dynamic>.from(e as Map)).toList();
        await _store.mutateList(LocalKeys.vocabulary, (list) {
          final pending = list.where((m) => isLocalId(m['_id'] as String?)).toList();
          // A pending local word that the server already has would be listed twice.
          final serverKeys = records
              .map((m) => '${(m['word'] as String?)?.toLowerCase()}|${m['targetLanguage']}')
              .toSet();
          final stillPending = pending.where((m) =>
              !serverKeys.contains('${(m['word'] as String?)?.toLowerCase()}|${m['targetLanguage']}'));
          list
            ..clear()
            ..addAll(stillPending)
            ..addAll(records);
        });
      } catch (_) {
        // offline: use the local copy
      }
    }
    return getCachedVocabulary(inFlashcard: inFlashcard);
  }

  Future<void> addToFlashcard(String id) => _setFlashcard(id, true);

  Future<void> removeFromFlashcard(String id) => _setFlashcard(id, false);

  Future<void> _setFlashcard(String id, bool value) async {
    final realId = await _sync.resolveId(id);
    await _store.mutateList(LocalKeys.vocabulary, (list) {
      for (final m in list) {
        if (m['_id'] == realId) m['inFlashcard'] = value;
      }
    });
    if (AppSession.isGuest) return;
    try {
      if (isLocalId(realId)) throw NetworkLikePending();
      if (value) {
        await _api.put('/vocabulary/$realId/flashcard');
      } else {
        await _api.delete('/vocabulary/$realId/flashcard');
      }
    } catch (e) {
      if (e is NetworkLikePending || shouldQueueOffline(e)) {
        await _sync.enqueue({'op': 'vocab.flashcard', 'id': realId, 'value': value});
      }
    }
  }

  Future<void> deleteVocabulary(String id) async {
    final realId = await _sync.resolveId(id);
    await _store.mutateList(
      LocalKeys.vocabulary,
      (list) => list.removeWhere((m) => m['_id'] == realId || m['_id'] == id),
    );
    if (isLocalId(realId)) {
      await _sync.removeWhere((op) =>
          (op['op'] == 'vocab.create' && op['localId'] == realId) ||
          (op['op'] == 'vocab.flashcard' && op['id'] == realId));
      return;
    }
    if (AppSession.isGuest) return;
    try {
      await _api.delete('/vocabulary/$realId');
    } catch (e) {
      if (shouldQueueOffline(e)) {
        await _sync.enqueue({'op': 'vocab.delete', 'id': realId});
      }
    }
  }

  // ===== System word bank (cached for offline) =====

  Future<List<VocabularyItem>> getSystemVocabulary({
    String? search,
    String? category,
  }) async {
    final unfiltered = (search == null || search.isEmpty) && (category == null || category.isEmpty);
    final query = <String, dynamic>{};
    if (search != null && search.isNotEmpty) query['search'] = search;
    if (category != null && category.isNotEmpty) query['category'] = category;
    try {
      final data = await _api.get(
        '/vocabulary/system',
        query: query.isEmpty ? null : query,
      ) as List<dynamic>;
      if (unfiltered) {
        await _store.writeJson(LocalKeys.systemVocab, data.take(3000).toList());
      }
      return data.map((e) => VocabularyItem.fromJson(e as Map<String, dynamic>)).toList();
    } catch (e) {
      final cached = await _store.readList(LocalKeys.systemVocab);
      if (cached.isEmpty) rethrow; // nothing downloaded yet: let the screen explain
      final mine = (await _store.readList(LocalKeys.vocabulary))
          .map((m) => (m['word'] as String?)?.toLowerCase())
          .toSet();
      final q = (search ?? '').toLowerCase();
      return cached
          .map(VocabularyItem.fromJson)
          .where((v) =>
              (category == null || category.isEmpty || v.category == category) &&
              (q.isEmpty ||
                  v.word.toLowerCase().contains(q) ||
                  (v.meaning ?? '').toLowerCase().contains(q)))
          .map((v) => VocabularyItem(
                id: v.id,
                word: v.word,
                meaning: v.meaning,
                sourceLanguage: v.sourceLanguage,
                targetLanguage: v.targetLanguage,
                source: v.source,
                inFlashcard: v.inFlashcard,
                audioUrl: v.audioUrl,
                phonetic: v.phonetic,
                inMyVocabulary: mine.contains(v.word.toLowerCase()),
                createdAt: v.createdAt,
                category: v.category,
              ))
          .toList();
    }
  }

  /// Topics of the system word bank (GET /vocabulary/system/categories),
  /// falling back to the cached list.
  Future<List<String>> getSystemCategories() async {
    try {
      final data = await _api.get('/vocabulary/system/categories') as List<dynamic>;
      final cats = data.cast<String>();
      await _store.writeJson(LocalKeys.systemCategories, cats);
      return cats;
    } catch (_) {
      final cached = await _store.readJson(LocalKeys.systemCategories);
      if (cached is List) return cached.whereType<String>().toList();
      return [];
    }
  }
}

/// Internal marker: the word has no server id yet, so the change must wait in
/// the queue behind its create operation.
class NetworkLikePending implements Exception {}
