import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import '../../core/theme.dart';
import '../../models/vocabulary.dart';
import '../../core/api_exception.dart';
import '../../core/backend_status.dart';
import '../../services/vocabulary_service.dart';
import '../../widgets/add_word_dialog.dart';
import '../../widgets/connection_banner.dart';
import 'flashcard_screen.dart';

/// Sổ tay từ (UI v3): 2 tab — "Sổ tay của tôi" và "Kho hệ thống".
class VocabularyScreen extends StatefulWidget {
  const VocabularyScreen({super.key});

  @override
  State<VocabularyScreen> createState() => _VocabularyScreenState();
}

class _VocabularyScreenState extends State<VocabularyScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppTheme.spaceMd, 8, AppTheme.spaceMd, 4,
              ),
              child: Text(
                'Từ vựng',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(AppTheme.spaceMd, 4, AppTheme.spaceMd, 0),
              child: ConnectionBanner(),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppTheme.spaceMd),
              child: TabBar(
                controller: _tabController,
                labelColor: AppTheme.coral,
                unselectedLabelColor: AppTheme.moss.withValues(alpha: .45),
                indicatorColor: AppTheme.coral,
                indicatorSize: TabBarIndicatorSize.tab,
                labelStyle: const TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w800,
                ),
                tabs: const [
                  Tab(text: 'Sổ tay của tôi'),
                  Tab(text: 'Kho hệ thống'),
                ],
              ),
            ),
            const Divider(height: 1, color: AppTheme.line),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: const [
                  _MyVocabularyTab(),
                  _SystemVocabularyTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════
//  TAB 1 — SỔ TAY CỦA TÔI
// ════════════════════════════════════════════════════════════

class _MyVocabularyTab extends StatefulWidget {
  const _MyVocabularyTab();

  @override
  State<_MyVocabularyTab> createState() => _MyVocabularyTabState();
}

class _MyVocabularyTabState extends State<_MyVocabularyTab>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  final _service = VocabularyService();
  final _tts = FlutterTts();
  List<VocabularyItem> _items = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _tts.stop();
    super.dispose();
  }

  Future<void> _load() async {
    // On-device words first (instant, works offline), then sync in background.
    final cached = await _service.getCachedVocabulary();
    if (!mounted) return;
    setState(() {
      _items = cached;
      _loading = false;
    });
    try {
      final items = await _service.getMyVocabulary();
      if (!mounted) return;
      setState(() => _items = items);
    } catch (_) {
      // Offline or guest: the local list above is already what the user needs.
    }
  }

  Future<void> _speak(VocabularyItem item) async {
    if (item.sourceLanguage != null) await _tts.setLanguage(item.sourceLanguage!);
    await _tts.speak(item.word);
  }

  Future<void> _addWord() async {
    final result = await showDialog<NewWord>(
      context: context,
      builder: (_) => const AddWordDialog(),
    );
    if (result == null) return;
    try {
      await _service.saveVocabulary(
        word: result.word,
        meaning: result.meaning,
        sourceLanguage: result.sourceCode,
        targetLanguage: result.targetCode,
        source: 'manual',
      );
      final items = await _service.getCachedVocabulary();
      if (!mounted) return;
      setState(() => _items = items);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Đã thêm "${result.word}" vào sổ tay')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Không thêm được từ: $e')));
    }
  }

  Future<void> _delete(VocabularyItem item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Xóa từ "${item.word}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Xóa'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await _service.deleteVocabulary(item.id);
      if (!mounted) return;
      setState(() => _items.removeWhere((v) => v.id == item.id));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Xóa từ thất bại: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    if (_loading) return const Center(child: CircularProgressIndicator());
    final addButton = OutlinedButton.icon(
      onPressed: _addWord,
      icon: const Icon(Icons.add_rounded, size: 18),
      label: const Text('Thêm từ'),
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(0, 36),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
      ),
    );
    if (_items.isEmpty) {
      return Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(AppTheme.spaceMd, 10, AppTheme.spaceMd, 4),
            child: Align(alignment: Alignment.centerRight, child: addButton),
          ),
          Expanded(
            child: Center(
              child: Text(
                'Chưa có từ nào.\nBấm "Thêm từ" để tự tạo, hoặc dịch một câu rồi chạm vào từ để lưu nhé.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppTheme.moss.withValues(alpha: .5),
                  fontSize: 14,
                  height: 1.6,
                ),
              ),
            ),
          ),
        ],
      );
    }
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(AppTheme.spaceMd, 10, AppTheme.spaceMd, 4),
          child: Row(
            children: [
              Text(
                '${_items.length} từ đã lưu',
                style: TextStyle(
                  fontSize: 12.5,
                  color: AppTheme.moss.withValues(alpha: .5),
                ),
              ),
              const Spacer(),
              addButton,
              const SizedBox(width: 8),
              FilledButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => FlashcardScreen(items: _items),
                  ),
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: AppTheme.coral,
                  minimumSize: const Size(0, 36),
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  textStyle: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                child: const Text('Luyện Flashcard'),
              ),
            ],
          ),
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: () {
                BackendStatus.reset(); // explicit refresh may retry the network
                return _load();
              },
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(
                AppTheme.spaceMd, 4, AppTheme.spaceMd, AppTheme.spaceMd,
              ),
              itemCount: _items.length,
              itemBuilder: (_, i) => _WordCard(
                item: _items[i],
                onSpeak: () => _speak(_items[i]),
                onDelete: () => _delete(_items[i]),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ════════════════════════════════════════════════════════════
//  TAB 2 — KHO HỆ THỐNG
// ════════════════════════════════════════════════════════════

class _SystemVocabularyTab extends StatefulWidget {
  const _SystemVocabularyTab();

  @override
  State<_SystemVocabularyTab> createState() => _SystemVocabularyTabState();
}

class _SystemVocabularyTabState extends State<_SystemVocabularyTab>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  final _service = VocabularyService();
  final _tts = FlutterTts();
  final _searchCtrl = TextEditingController();

  List<VocabularyItem> _items = [];
  List<String> _categories = [];
  String _search = '';
  String? _selectedCategory; // null = tất cả
  bool _loading = true;
  bool _categoriesLoading = true;
  // True when the word bank could not be loaded and none was cached yet.
  bool _unavailable = false;

  @override
  void initState() {
    super.initState();
    _loadCategories();
    _loadWords();
    _searchCtrl.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _tts.stop();
    _searchCtrl.removeListener(_onSearchChanged);
    _searchCtrl.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    final q = _searchCtrl.text.trim();
    if (q != _search) {
      _search = q;
      _loadWords();
    }
  }

  Future<void> _loadCategories() async {
    try {
      final cats = await _service.getSystemCategories();
      if (!mounted) return;
      setState(() {
        _categories = cats;
        _categoriesLoading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _categoriesLoading = false);
    }
  }

  Future<void> _loadWords() async {
    if (!mounted) return;
    setState(() => _loading = true);
    try {
      final items = await _service.getSystemVocabulary(
        search: _search.isEmpty ? null : _search,
        category: _selectedCategory,
      );
      if (!mounted) return;
      setState(() {
        _items = items;
        _unavailable = false;
      });
    } catch (e) {
      if (!mounted) return;
      if (e is NetworkException) {
        // Not an error: the bank simply has not been downloaded to this device.
        setState(() {
          _items = [];
          _unavailable = true;
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Không tải được kho từ vựng: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _selectCategory(String? cat) {
    if (_selectedCategory == cat) return;
    setState(() => _selectedCategory = cat);
    _loadWords();
  }

  Future<void> _speak(VocabularyItem item) async {
    if (item.sourceLanguage != null) await _tts.setLanguage(item.sourceLanguage!);
    await _tts.speak(item.word);
  }

  Future<void> _save(VocabularyItem item) async {
    try {
      await _service.saveVocabulary(
        word: item.word,
        meaning: item.meaning ?? '',
        sourceLanguage: item.sourceLanguage,
        targetLanguage: item.targetLanguage,
        source: 'system',
      );
      if (!mounted) return;
      setState(() {
        final idx = _items.indexWhere((v) => v.id == item.id);
        if (idx != -1) {
          _items[idx] = VocabularyItem(
            id: item.id,
            word: item.word,
            meaning: item.meaning,
            sourceLanguage: item.sourceLanguage,
            targetLanguage: item.targetLanguage,
            source: item.source,
            inFlashcard: item.inFlashcard,
            audioUrl: item.audioUrl,
            phonetic: item.phonetic,
            inMyVocabulary: true,
            createdAt: item.createdAt,
          );
        }
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Đã lưu "${item.word}" vào sổ tay'),
          backgroundColor: AppTheme.moss,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Lưu từ thất bại: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Thanh tìm kiếm ──────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppTheme.spaceMd, 12, AppTheme.spaceMd, 8,
          ),
          child: TextField(
            controller: _searchCtrl,
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              hintText: 'Tìm từ trong kho hệ thống…',
              hintStyle: TextStyle(
                fontSize: 14,
                color: AppTheme.moss.withValues(alpha: .4),
              ),
              prefixIcon: Icon(
                Icons.search_rounded,
                size: 20,
                color: AppTheme.moss.withValues(alpha: .5),
              ),
              suffixIcon: _search.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.close_rounded, size: 18),
                      color: AppTheme.moss.withValues(alpha: .5),
                      onPressed: () {
                        _searchCtrl.clear();
                        FocusScope.of(context).unfocus();
                      },
                    )
                  : null,
              filled: true,
              fillColor: AppTheme.ivory,
              contentPadding: const EdgeInsets.symmetric(vertical: 10),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: AppTheme.line),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: AppTheme.line),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: AppTheme.moss, width: 1.5),
              ),
            ),
          ),
        ),

        // ── Chip chủ đề ──────────────────────────────────
        if (!_categoriesLoading && _categories.isNotEmpty)
          SizedBox(
            height: 38,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: AppTheme.spaceMd),
              children: [
                // Chip "Tất cả"
                _CategoryChip(
                  label: 'Tất cả',
                  selected: _selectedCategory == null,
                  onTap: () => _selectCategory(null),
                ),
                ..._categories.map(
                  (cat) => _CategoryChip(
                    label: cat,
                    selected: _selectedCategory == cat,
                    onTap: () => _selectCategory(cat),
                  ),
                ),
              ],
            ),
          ),

        if (!_categoriesLoading && _categories.isNotEmpty)
          const SizedBox(height: 6),

        // ── Số kết quả ───────────────────────────────────
        if (!_loading)
          Padding(
            padding: const EdgeInsets.fromLTRB(AppTheme.spaceMd, 0, AppTheme.spaceMd, 4),
            child: Text(
              _buildResultLabel(),
              style: TextStyle(
                fontSize: 12,
                color: AppTheme.moss.withValues(alpha: .45),
              ),
            ),
          ),

        // ── Danh sách từ ─────────────────────────────────
        if (_loading)
          const Expanded(child: Center(child: CircularProgressIndicator()))
        else if (_items.isEmpty)
          Expanded(
            child: Center(
              child: Text(
                _buildEmptyLabel(),
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppTheme.moss.withValues(alpha: .5),
                  fontSize: 14,
                  height: 1.6,
                ),
              ),
            ),
          )
        else
          Expanded(
            child: RefreshIndicator(
              onRefresh: () {
                BackendStatus.reset();
                return _loadWords();
              },
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(
                  AppTheme.spaceMd, 0, AppTheme.spaceMd, AppTheme.spaceMd,
                ),
                itemCount: _items.length,
                itemBuilder: (_, i) => _SystemWordCard(
                  item: _items[i],
                  onSpeak: () => _speak(_items[i]),
                  onSave: _items[i].inMyVocabulary ? null : () => _save(_items[i]),
                ),
              ),
            ),
          ),
      ],
    );
  }

  String _buildResultLabel() {
    final n = _items.length;
    if (_selectedCategory != null && _search.isNotEmpty) {
      return '$n từ • "$_selectedCategory" • "$_search"';
    } else if (_selectedCategory != null) {
      return '$n từ trong chủ đề "$_selectedCategory"';
    } else if (_search.isNotEmpty) {
      return '$n kết quả cho "$_search"';
    }
    return '$n từ trong kho hệ thống';
  }

  String _buildEmptyLabel() {
    if (_unavailable) {
      return 'Kho từ vựng chưa được tải về máy.\nĐăng nhập và kết nối mạng một lần,\nlần sau bạn xem được ngoại tuyến.';
    }
    if (_selectedCategory != null && _search.isNotEmpty) {
      return 'Không tìm thấy từ "$_search"\ntrong chủ đề "$_selectedCategory".';
    } else if (_selectedCategory != null) {
      return 'Chủ đề "$_selectedCategory"\nchưa có từ nào.';
    } else if (_search.isNotEmpty) {
      return 'Không tìm thấy từ "$_search".';
    }
    return 'Kho từ vựng hệ thống chưa có từ nào.';
  }
}

// ════════════════════════════════════════════════════════════
//  WIDGETS
// ════════════════════════════════════════════════════════════

class _CategoryChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _CategoryChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? AppTheme.moss : AppTheme.ivory,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected ? AppTheme.moss : AppTheme.line,
            width: selected ? 0 : 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: selected ? AppTheme.ivory : AppTheme.moss.withValues(alpha: .75),
          ),
        ),
      ),
    );
  }
}

class _WordCard extends StatelessWidget {
  final VocabularyItem item;
  final VoidCallback onSpeak;
  final VoidCallback onDelete;

  const _WordCard({
    required this.item,
    required this.onSpeak,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final isFresh = item.createdAt != null &&
        DateTime.now().difference(item.createdAt!).inHours < 24;
    final dir = (item.sourceLanguage != null && item.targetLanguage != null)
        ? '${item.sourceLanguage!.toUpperCase()} → ${item.targetLanguage!.toUpperCase()}'
        : null;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.fromLTRB(15, 12, 8, 12),
      decoration: BoxDecoration(
        color: AppTheme.ivory,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.line),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        item.word,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    if (item.phonetic != null) ...[
                      const SizedBox(width: 6),
                      Text(
                        item.phonetic!,
                        style: TextStyle(
                          fontSize: 12,
                          color: AppTheme.moss.withValues(alpha: .5),
                        ),
                      ),
                    ],
                    if (isFresh) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 1.5,
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.coralTint,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: const Text(
                          'mới lưu',
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.cranberry,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                if (item.meaning != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    item.meaning!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.moss,
                    ),
                  ),
                ],
                if (dir != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    dir,
                    style: TextStyle(
                      fontSize: 11,
                      color: AppTheme.moss.withValues(alpha: .45),
                    ),
                  ),
                ],
              ],
            ),
          ),
          IconButton(
            tooltip: 'Phát âm',
            icon: const Icon(Icons.volume_up_rounded, size: 20),
            color: AppTheme.moss.withValues(alpha: .6),
            onPressed: onSpeak,
          ),
          IconButton(
            tooltip: 'Xóa từ',
            icon: const Icon(Icons.delete_outline_rounded, size: 20),
            color: AppTheme.moss.withValues(alpha: .6),
            onPressed: onDelete,
          ),
        ],
      ),
    );
  }
}

class _SystemWordCard extends StatelessWidget {
  final VocabularyItem item;
  final VoidCallback onSpeak;
  final VoidCallback? onSave;

  const _SystemWordCard({
    required this.item,
    required this.onSpeak,
    required this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    final dir = (item.sourceLanguage != null && item.targetLanguage != null)
        ? '${item.sourceLanguage!.toUpperCase()} → ${item.targetLanguage!.toUpperCase()}'
        : null;
    final saved = item.inMyVocabulary;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.fromLTRB(15, 12, 8, 12),
      decoration: BoxDecoration(
        color: saved ? AppTheme.moss.withValues(alpha: .04) : AppTheme.ivory,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: saved ? AppTheme.moss.withValues(alpha: .2) : AppTheme.line,
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        item.word,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    if (item.phonetic != null) ...[
                      const SizedBox(width: 6),
                      Text(
                        item.phonetic!,
                        style: TextStyle(
                          fontSize: 12,
                          color: AppTheme.moss.withValues(alpha: .5),
                        ),
                      ),
                    ],
                    if (saved) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 1.5,
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.moss.withValues(alpha: .12),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          'đã lưu',
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.moss.withValues(alpha: .75),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                if (item.meaning != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    item.meaning!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.moss,
                    ),
                  ),
                ],
                if (dir != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    dir,
                    style: TextStyle(
                      fontSize: 11,
                      color: AppTheme.moss.withValues(alpha: .45),
                    ),
                  ),
                ],
              ],
            ),
          ),
          IconButton(
            tooltip: 'Phát âm',
            icon: const Icon(Icons.volume_up_rounded, size: 20),
            color: AppTheme.moss.withValues(alpha: .6),
            onPressed: onSpeak,
          ),
          IconButton(
            tooltip: saved ? 'Đã có trong sổ tay' : 'Lưu vào sổ tay',
            icon: Icon(
              saved ? Icons.bookmark_rounded : Icons.bookmark_add_outlined,
              size: 22,
            ),
            color: saved ? AppTheme.moss : AppTheme.moss.withValues(alpha: .55),
            onPressed: onSave,
          ),
        ],
      ),
    );
  }
}
