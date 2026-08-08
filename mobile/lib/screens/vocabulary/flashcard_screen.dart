import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import '../../core/theme.dart';
import '../../models/vocabulary.dart';
import '../../services/vocabulary_service.dart';

class FlashcardScreen extends StatefulWidget {
  const FlashcardScreen({super.key});

  @override
  State<FlashcardScreen> createState() => _FlashcardScreenState();
}

class _FlashcardScreenState extends State<FlashcardScreen> {
  final _service = VocabularyService();
  final _tts = FlutterTts();
  final _pageController = PageController();

  List<VocabularyItem> _cards = [];
  bool _loading = true;
  bool _showMeaning = false;
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _loadCards();
  }

  Future<void> _loadCards() async {
    try {
      final cards = await _service.getMyVocabulary(inFlashcard: true);
      if (!mounted) return;
      setState(() {
        _cards = cards;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Không tải được flashcard: $e')));
    }
  }

  Future<void> _speak(String word) async {
    await _tts.speak(word);
  }

  Future<void> _removeCard(VocabularyItem card) async {
    try {
      await _service.removeFromFlashcard(card.id);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Đã bỏ khỏi Flashcard')));
      setState(() {
        _cards = _cards.where((item) => item.id != card.id).toList();
        _showMeaning = false;
        if (_currentIndex >= _cards.length && _cards.isNotEmpty) {
          _currentIndex = _cards.length - 1;
        }
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Thao tác thất bại: $e')));
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    _tts.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Luyện Flashcard')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _cards.isEmpty
              ? _buildEmptyState()
              : PageView.builder(
                  controller: _pageController,
                  itemCount: _cards.length,
                  onPageChanged: (index) => setState(() {
                    _currentIndex = index;
                    _showMeaning = false;
                  }),
                  itemBuilder: (context, index) =>
                      _buildCard(_cards[index], index),
                ),
    );
  }

  Widget _buildCard(VocabularyItem card, int index) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppTheme.spaceLg,
        12,
        AppTheme.spaceLg,
        AppTheme.spaceLg,
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Ôn tập hôm nay',
                style: TextStyle(
                  color: AppTheme.coral,
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.2,
                ),
              ),
              Text(
                '${index + 1} / ${_cards.length}',
                style: TextStyle(
                  color: AppTheme.moss.withValues(alpha: .55),
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const Spacer(),
          GestureDetector(
            onTap: () => setState(() => _showMeaning = !_showMeaning),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: double.infinity,
              constraints: const BoxConstraints(minHeight: 300),
              padding: const EdgeInsets.all(AppTheme.spaceLg),
              decoration: BoxDecoration(
                color: _showMeaning ? AppTheme.moss : AppTheme.ivory,
                borderRadius: BorderRadius.circular(28),
                border: Border.all(
                  color: _showMeaning ? AppTheme.moss : AppTheme.line,
                ),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x1A1B4B43),
                    blurRadius: 20,
                    offset: Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    _showMeaning
                        ? Icons.lightbulb_outline_rounded
                        : Icons.bookmark_rounded,
                    color: _showMeaning ? AppTheme.coral : AppTheme.coral,
                    size: 24,
                  ),
                  const SizedBox(height: 22),
                  Text(
                    card.word,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: 'serif',
                      fontSize: 36,
                      height: 1.1,
                      fontWeight: FontWeight.w800,
                      color: _showMeaning ? AppTheme.ivory : AppTheme.moss,
                    ),
                  ),
                  if (card.phonetic != null && card.phonetic!.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      card.phonetic!,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontStyle: FontStyle.italic,
                        fontSize: 15,
                        color: _showMeaning
                            ? AppTheme.ivory.withValues(alpha: .8)
                            : AppTheme.moss.withValues(alpha: .55),
                      ),
                    ),
                  ],
                  const SizedBox(height: 22),
                  IconButton(
                    tooltip: 'Phát âm',
                    style: IconButton.styleFrom(
                      backgroundColor: _showMeaning
                          ? AppTheme.ivory.withValues(alpha: .12)
                          : AppTheme.sand,
                    ),
                    icon: Icon(
                      Icons.volume_up_outlined,
                      color: _showMeaning ? AppTheme.ivory : AppTheme.moss,
                    ),
                    onPressed: () => _speak(card.word),
                  ),
                  if (_showMeaning) ...[
                    const SizedBox(height: 22),
                    const Divider(color: Color(0x44FFFDF9)),
                    const SizedBox(height: 16),
                    Text(
                      card.meaning ?? '(chưa có nghĩa)',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: AppTheme.ivory,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        height: 1.35,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            _showMeaning
                ? 'Chạm vào thẻ để ẩn nghĩa'
                : 'Chạm vào thẻ để xem nghĩa',
            style: TextStyle(
              color: AppTheme.moss.withValues(alpha: .55),
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: () => _removeCard(card),
            icon: const Icon(Icons.remove_circle_outline, size: 18),
            label: const Text('Bỏ khỏi Flashcard'),
          ),
          const Spacer(),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spaceXl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.style_outlined, size: 46, color: AppTheme.sage),
            const SizedBox(height: 18),
            Text(
              'Chưa có thẻ để ôn tập',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 7),
            Text(
              'Thêm từ yêu thích vào Flashcard để bắt đầu.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppTheme.moss.withValues(alpha: .6)),
            ),
          ],
        ),
      ),
    );
  }
}
