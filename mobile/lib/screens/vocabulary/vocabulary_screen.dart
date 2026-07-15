import 'package:flutter/material.dart';
import '../../models/vocabulary.dart';
import '../../services/vocabulary_service.dart';
import 'flashcard_screen.dart';

class VocabularyScreen extends StatefulWidget {
  const VocabularyScreen({super.key});

  @override
  State<VocabularyScreen> createState() => _VocabularyScreenState();
}

class _VocabularyScreenState extends State<VocabularyScreen> with SingleTickerProviderStateMixin {
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

  Future<void> _loadData() async {
    setState(() => _loading = true);
    try {
      final results = await Future.wait([_service.getMyVocabulary(), _service.getSystemVocabulary()]);
      setState(() {
        _myVocab = results[0];
        _systemVocab = results[1];
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Không tải được từ vựng: $e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _addManualWord() async {
    final wordController = TextEditingController();
    final meaningController = TextEditingController();

    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Thêm từ vựng'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: wordController, decoration: const InputDecoration(labelText: 'Từ vựng')),
            TextField(controller: meaningController, decoration: const InputDecoration(labelText: 'Nghĩa')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Hủy')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Lưu')),
        ],
      ),
    );

    if (saved == true && wordController.text.trim().isNotEmpty) {
      try {
        await _service.saveVocabulary(word: wordController.text.trim(), meaning: meaningController.text.trim(), source: 'manual');
        _loadData();
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Lưu thất bại: $e')));
      }
    }
  }

  Future<void> _addToFlashcard(VocabularyItem item) async {
    try {
      await _service.addToFlashcard(item.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Đã thêm vào Flashcard')));
      _loadData();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Thao tác thất bại: $e')));
    }
  }

  Future<void> _deleteVocab(VocabularyItem item) async {
    try {
      await _service.deleteVocabulary(item.id);
      _loadData();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Xóa thất bại: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Từ vựng'),
        bottom: TabBar(controller: _tabController, tabs: const [Tab(text: 'Yêu thích'), Tab(text: 'Kho hệ thống')]),
        actions: [
          IconButton(
            icon: const Icon(Icons.style_outlined),
            tooltip: 'Luyện tập Flashcard',
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const FlashcardScreen())),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(onPressed: _addManualWord, child: const Icon(Icons.add)),
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
      return const Center(child: Text('Chưa có từ vựng yêu thích nào.\nBấm + để thêm.', textAlign: TextAlign.center));
    }
    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView.builder(
        itemCount: _myVocab.length,
        itemBuilder: (context, i) {
          final item = _myVocab[i];
          return ListTile(
            title: Text(item.word),
            subtitle: Text(item.meaning ?? ''),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: Icon(item.inFlashcard ? Icons.style : Icons.style_outlined,
                      color: item.inFlashcard ? Theme.of(context).colorScheme.primary : null),
                  tooltip: 'Thêm vào Flashcard',
                  onPressed: item.inFlashcard ? null : () => _addToFlashcard(item),
                ),
                IconButton(icon: const Icon(Icons.delete_outline), onPressed: () => _deleteVocab(item)),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildSystemVocabList() {
    if (_systemVocab.isEmpty) {
      return const Center(child: Text('Kho từ vựng hệ thống chưa có dữ liệu.'));
    }
    return ListView.builder(
      itemCount: _systemVocab.length,
      itemBuilder: (context, i) {
        final item = _systemVocab[i];
        return ListTile(
          title: Text(item.word),
          subtitle: Text(item.meaning ?? ''),
          trailing: IconButton(
            icon: const Icon(Icons.bookmark_add_outlined),
            tooltip: 'Lưu vào từ vựng của tôi',
            onPressed: () async {
              await _service.saveVocabulary(
                word: item.word,
                meaning: item.meaning,
                sourceLanguage: item.sourceLanguage,
                targetLanguage: item.targetLanguage,
              );
              _loadData();
            },
          ),
        );
      },
    );
  }
}
