import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
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

  @override
  void initState() {
    super.initState();
    _loadCards();
  }

  Future<void> _loadCards() async {
    try {
      final cards = await _service.getMyVocabulary(inFlashcard: true);
      setState(() {
        _cards = cards;
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Không tải được flashcard: $e')));
    }
  }

  Future<void> _speak(String word) async {
    await _tts.speak(word);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Luyện tập Flashcard')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _cards.isEmpty
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Text(
                      'Chưa có từ vựng nào trong Flashcard.\nHãy thêm từ vựng yêu thích vào Flashcard trước.',
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              : PageView.builder(
                  controller: _pageController,
                  itemCount: _cards.length,
                  onPageChanged: (_) => setState(() => _showMeaning = false),
                  itemBuilder: (context, i) {
                    final card = _cards[i];
                    return Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        children: [
                          Text('${i + 1} / ${_cards.length}', style: const TextStyle(color: Colors.grey)),
                          const Spacer(),
                          GestureDetector(
                            onTap: () => setState(() => _showMeaning = !_showMeaning),
                            child: Card(
                              elevation: 3,
                              child: Container(
                                width: double.infinity,
                                height: 260,
                                alignment: Alignment.center,
                                padding: const EdgeInsets.all(24),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(card.word, style: Theme.of(context).textTheme.headlineMedium, textAlign: TextAlign.center),
                                    const SizedBox(height: 16),
                                    IconButton(
                                      icon: const Icon(Icons.volume_up_outlined),
                                      onPressed: () => _speak(card.word),
                                    ),
                                    if (_showMeaning) ...[
                                      const Divider(),
                                      Text(card.meaning ?? '(chưa có nghĩa)', textAlign: TextAlign.center),
                                    ],
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            _showMeaning ? 'Chạm vào thẻ để ẩn nghĩa' : 'Chạm vào thẻ để xem nghĩa',
                            style: const TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                          const Spacer(),
                        ],
                      ),
                    );
                  },
                ),
    );
  }
}
