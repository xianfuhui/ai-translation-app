import 'package:flutter/material.dart';
import '../../core/theme.dart';
import '../../models/vocabulary.dart';
import '../../services/vocabulary_service.dart';
import 'flashcard_screen.dart';

class VocabularyScreen extends StatefulWidget {
  const VocabularyScreen({super.key});

  @override
  State<VocabularyScreen> createState() => _VocabularyScreenState();
}

class _VocabularyScreenState extends State<VocabularyScreen>
    with SingleTickerProviderStateMixin {
  final _service = VocabularyService();
  late TabController _tabController;

  List<VocabularyItem> _myVocab = [];
  List<VocabularyItem> _systemVocab = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    try {
      final results = await Future.wait([
        _service.getMyVocabulary(),
        _service.getSystemVocabulary(),
      ]);
      if (!mounted) return;
      setState(() {
        _myVocab = results[0];
        _systemVocab = results[1];
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Không tải được từ vựng: $e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _addManualWord() async {
    final formKey = GlobalKey<FormState>();
    final wordController = TextEditingController();
    final meaningController = TextEditingController();

    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Thêm từ vựng'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: wordController,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: 'Từ vựng *',
                  prefixIcon: Icon(Icons.translate_rounded),
                ),
                validator: (value) => (value == null || value.trim().isEmpty)
                    ? 'Vui lòng nhập từ vựng'
                    : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: meaningController,
                decoration: const InputDecoration(
                  labelText: 'Nghĩa *',
                  prefixIcon: Icon(Icons.notes_rounded),
                ),
                validator: (value) => (value == null || value.trim().isEmpty)
                    ? 'Vui lòng nhập nghĩa của từ'
                    : null,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                Navigator.pop(context, true);
              }
            },
            child: const Text('Lưu từ'),
          ),
        ],
      ),
    );

    if (saved == true) {
      try {
        await _service.saveVocabulary(
          word: wordController.text.trim(),
          meaning: meaningController.text.trim(),
          source: 'manual',
        );
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Đã thêm từ vào sổ tay')));
        _loadData();
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Lưu thất bại: $e')));
      }
    }
    wordController.dispose();
    meaningController.dispose();
  }

  Future<void> _toggleFlashcard(VocabularyItem item) async {
    try {
      if (item.inFlashcard) {
        await _service.removeFromFlashcard(item.id);
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Đã bỏ khỏi Flashcard')));
      } else {
        await _service.addToFlashcard(item.id);
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Đã thêm vào Flashcard')));
      }
      _loadData();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Thao tác thất bại: $e')));
    }
  }

  Future<void> _deleteVocab(VocabularyItem item) async {
    try {
      await _service.deleteVocabulary(item.id);
      _loadData();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Xóa thất bại: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sổ tay từ vựng'),
        actions: [
          IconButton(
            tooltip: 'Luyện tập Flashcard',
            icon: const Icon(Icons.style_outlined),
            onPressed: () => Navigator.of(
              context,
            ).push(MaterialPageRoute(builder: (_) => const FlashcardScreen())),
          ),
          const SizedBox(width: 6),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Của tôi'),
            Tab(text: 'Kho hệ thống'),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addManualWord,
        backgroundColor: AppTheme.coral,
        foregroundColor: AppTheme.ivory,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Thêm từ'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [_buildMyVocabList(), _buildSystemVocabList()],
            ),
    );
  }

  Widget _buildMyVocabList() {
    if (_myVocab.isEmpty) {
      return _buildEmpty(
        'Chưa có từ nào trong sổ tay',
        'Chạm “Thêm từ” hoặc lưu trực tiếp từ bản dịch.',
      );
    }
    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(
          AppTheme.spaceMd,
          AppTheme.spaceMd,
          AppTheme.spaceMd,
          110,
        ),
        itemCount: _myVocab.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (context, index) =>
            _buildVocabTile(_myVocab[index], isMine: true),
      ),
    );
  }

  Widget _buildSystemVocabList() {
    if (_systemVocab.isEmpty) {
      return _buildEmpty(
        'Kho hệ thống đang trống',
        'Những từ được chọn sẽ xuất hiện ở đây.',
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(
        AppTheme.spaceMd,
        AppTheme.spaceMd,
        AppTheme.spaceMd,
        110,
      ),
      itemCount: _systemVocab.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) =>
          _buildVocabTile(_systemVocab[index], isMine: false),
    );
  }

  Widget _buildVocabTile(VocabularyItem item, {required bool isMine}) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 38,
              height: 38,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppTheme.coralTint,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.bookmark_rounded,
                color: AppTheme.coral,
                size: 19,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.word,
                    style: const TextStyle(
                      fontFamily: 'serif',
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    item.meaning?.isNotEmpty == true
                        ? item.meaning!
                        : 'Chưa có nghĩa',
                    style: TextStyle(
                      color: AppTheme.moss.withValues(alpha: .64),
                      fontSize: 13,
                    ),
                  ),
                  if (item.sourceLanguage != null &&
                      item.targetLanguage != null) ...[
                    const SizedBox(height: 7),
                    Text(
                      '${item.sourceLanguage} → ${item.targetLanguage}',
                      style: const TextStyle(
                        color: AppTheme.coral,
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (isMine) ...[
              IconButton(
                tooltip: item.inFlashcard
                    ? 'Bỏ khỏi Flashcard'
                    : 'Thêm vào Flashcard',
                icon: Icon(
                  item.inFlashcard ? Icons.style_rounded : Icons.style_outlined,
                  color: item.inFlashcard
                      ? AppTheme.coral
                      : AppTheme.moss.withValues(alpha: .45),
                ),
                onPressed: () => _toggleFlashcard(item),
              ),
              IconButton(
                tooltip: 'Xóa từ',
                icon: const Icon(
                  Icons.delete_outline_rounded,
                  color: AppTheme.cranberry,
                ),
                onPressed: () => _deleteVocab(item),
              ),
            ] else
              IconButton(
                tooltip: 'Lưu vào sổ tay',
                icon: const Icon(
                  Icons.bookmark_add_outlined,
                  color: AppTheme.coral,
                ),
                onPressed: () async {
                  try {
                    await _service.saveVocabulary(
                      word: item.word,
                      meaning: item.meaning ?? '',
                      sourceLanguage: item.sourceLanguage,
                      targetLanguage: item.targetLanguage,
                    );
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Đã lưu vào sổ tay')),
                    );
                    _loadData();
                  } catch (e) {
                    if (!mounted) return;
                    ScaffoldMessenger.of(
                      context,
                    ).showSnackBar(SnackBar(content: Text('Lưu thất bại: $e')));
                  }
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmpty(String title, String description) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spaceXl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.menu_book_outlined,
              size: 42,
              color: AppTheme.sage,
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: Theme.of(context).textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              description,
              style: TextStyle(color: AppTheme.moss.withValues(alpha: .6)),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
