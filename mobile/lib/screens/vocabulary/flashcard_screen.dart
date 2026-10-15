import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import '../../core/theme.dart';
import '../../models/vocabulary.dart';

/// Luyện Flashcard (UI v2): thẻ to ở giữa — chạm để lật xem nghĩa;
/// "🔊 Phát âm" + "Thẻ tiếp theo →" xoay vòng qua toàn bộ từ đã lưu.
class FlashcardScreen extends StatefulWidget {
  final List<VocabularyItem> items;

  const FlashcardScreen({super.key, required this.items});

  @override
  State<FlashcardScreen> createState() => _FlashcardScreenState();
}

class _FlashcardScreenState extends State<FlashcardScreen> {
  final _tts = FlutterTts();
  int _index = 0;
  bool _flipped = false;

  VocabularyItem get _current => widget.items[_index % widget.items.length];

  @override
  void dispose() {
    _tts.stop();
    super.dispose();
  }

  Future<void> _speak() async {
    if (_current.sourceLanguage != null) {
      await _tts.setLanguage(_current.sourceLanguage!);
    }
    await _tts.speak(_current.word);
  }

  void _next() {
    setState(() {
      _index++;
      _flipped = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final total = widget.items.length;
    final position = (_index % total) + 1;

    return Scaffold(
      appBar: AppBar(title: const Text('Flashcard')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.spaceMd),
          child: Column(
            children: [
              Text(
                'Ôn tập hôm nay · $position / $total',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.moss.withValues(alpha: .55),
                ),
              ),
              const SizedBox(height: 16),
              Semantics(
                button: true,
                label: 'Lật thẻ để xem nghĩa',
                child: GestureDetector(
                  onTap: () => setState(() => _flipped = !_flipped),
                  child: Container(
                    width: double.infinity,
                    constraints: const BoxConstraints(minHeight: 300),
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: AppTheme.ivory,
                      borderRadius: BorderRadius.circular(26),
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.moss.withValues(alpha: .08),
                          blurRadius: 24,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          _current.word,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 30,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.moss,
                          ),
                        ),
                        if (_current.phonetic != null) ...[
                          const SizedBox(height: 6),
                          Text(
                            _current.phonetic!,
                            style: TextStyle(
                              fontSize: 14,
                              color: AppTheme.moss.withValues(alpha: .5),
                            ),
                          ),
                        ],
                        const SizedBox(height: 14),
                        if (_flipped)
                          Text(
                            _current.meaning ?? '—',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 23,
                              fontWeight: FontWeight.w800,
                              color: AppTheme.coral,
                            ),
                          )
                        else
                          Text(
                            'Chạm vào thẻ để xem nghĩa',
                            style: TextStyle(
                              fontSize: 13,
                              color: AppTheme.moss.withValues(alpha: .45),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _speak,
                      icon: const Icon(Icons.volume_up_rounded, size: 18),
                      label: const Text('Phát âm'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: _next,
                      style: FilledButton.styleFrom(
                        backgroundColor: AppTheme.coral,
                      ),
                      icon: const Icon(Icons.arrow_forward_rounded, size: 18),
                      label: const Text('Thẻ tiếp theo'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
