import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import '../core/theme.dart';
import 'add_word_dialog.dart';
import '../services/vocabulary_service.dart';

/// Từ = chuỗi chữ/số Unicode (cho phép ' và - ở giữa từ, vd "don't", "well-known").
/// Chữ CJK không có dấu cách nên cả cụm liền nhau được tính là 1 "từ".
final RegExp _wordPattern =
    RegExp(r"[\p{L}\p{N}][\p{L}\p{N}'’\-]*", unicode: true);

/// Một từ đã chọn: nằm ở đâu trong câu nào (để ghép các từ liền nhau thành cụm).
class _PickedWord {
  final String sentenceId;
  final String text; // cả câu chứa từ này
  final int start;
  final int end;
  final String wordLang;
  final String meaningLang;
  const _PickedWord(
    this.sentenceId,
    this.text,
    this.start,
    this.end,
    this.wordLang,
    this.meaningLang,
  );
}

/// Kết quả sau khi gộp: 1 từ hoặc 1 cụm từ cần lưu.
class SelectedPhrase {
  final String text;
  final String wordLang;
  final String meaningLang;
  const SelectedPhrase(this.text, this.wordLang, this.meaningLang);
}

/// Tập các từ đang được chọn trên 1 màn hình. Chạm từ = chọn / bỏ chọn; chỉ khi
/// bấm "Lưu vào sổ tay" ở thanh chốt thì mới lưu.
///  - Chọn 1 từ riêng lẻ  -> lưu đúng từ đó.
///  - Chọn nhiều từ LIỀN NHAU trong cùng 1 câu -> gộp lại, lưu nguyên cụm.
class WordSelection extends ChangeNotifier {
  final Map<String, _PickedWord> _items = {};

  String _key(String sentenceId, int start) => '$sentenceId#$start';

  bool isSelected(String sentenceId, int start) =>
      _items.containsKey(_key(sentenceId, start));

  bool get isEmpty => _items.isEmpty;

  /// Số mục sẽ lưu (từ đơn hoặc cụm), sau khi gộp các từ liền nhau.
  int get count => phrases().length;

  void toggle(_PickedWord w) {
    final k = _key(w.sentenceId, w.start);
    if (_items.remove(k) == null) _items[k] = w;
    notifyListeners();
  }

  void clear() {
    if (_items.isEmpty) return;
    _items.clear();
    notifyListeners();
  }

  /// Gộp các từ liền nhau (giữa chúng không còn từ nào khác, chỉ có dấu cách /
  /// dấu câu) trong cùng 1 câu thành cụm; các từ rời nhau thành mục riêng.
  List<SelectedPhrase> phrases() {
    final bySentence = <String, List<_PickedWord>>{};
    for (final w in _items.values) {
      bySentence.putIfAbsent(w.sentenceId, () => []).add(w);
    }
    final result = <SelectedPhrase>[];
    for (final group in bySentence.values) {
      group.sort((a, b) => a.start.compareTo(b.start));
      var runStart = group.first;
      var runEnd = group.first;
      void flush() => result.add(SelectedPhrase(
            runStart.text.substring(runStart.start, runEnd.end),
            runStart.wordLang,
            runStart.meaningLang,
          ));
      for (final w in group.skip(1)) {
        final between = w.text.substring(runEnd.end, w.start);
        final adjacent = !_wordPattern.hasMatch(between);
        if (adjacent) {
          runEnd = w;
        } else {
          flush();
          runStart = w;
          runEnd = w;
        }
      }
      flush();
    }
    return result;
  }
}

class _Token {
  final String text;
  final int start;
  final int end;
  final bool isWord;
  final TapGestureRecognizer? recognizer;
  const _Token(this.text, this.start, this.end, this.isWord, this.recognizer);
}

/// Đoạn chữ mà từng từ chạm được để CHỌN (tô nền khi đã chọn). Chọn 1 hoặc
/// nhiều từ, rồi bấm nút chốt ở [WordSelectionBar] để lưu vào sổ tay.
class TappableWords extends StatefulWidget {
  final String text;
  final TextStyle? style;
  final int? maxLines;
  final TextOverflow? overflow;
  final WordSelection selection;

  /// Định danh duy nhất của câu này trên màn hình (vd "<idMục>:<lượt>:nguồn").
  /// Dùng để biết các từ nào cùng 1 câu và liền nhau -> ghép thành cụm.
  final String sentenceId;
  final String wordLang; // ngôn ngữ của đoạn chữ này
  final String meaningLang; // ngôn ngữ dùng để ghi nghĩa

  const TappableWords({
    super.key,
    required this.text,
    required this.selection,
    required this.sentenceId,
    required this.wordLang,
    required this.meaningLang,
    this.style,
    this.maxLines,
    this.overflow,
  });

  @override
  State<TappableWords> createState() => _TappableWordsState();
}

class _TappableWordsState extends State<TappableWords> {
  List<_Token> _tokens = const [];
  String? _builtFor;

  void _disposeRecognizers() {
    for (final t in _tokens) {
      t.recognizer?.dispose();
    }
  }

  void _tokenize() {
    _disposeRecognizers();
    final text = widget.text;
    final tokens = <_Token>[];
    var last = 0;
    for (final m in _wordPattern.allMatches(text)) {
      if (m.start > last) {
        tokens.add(_Token(text.substring(last, m.start), last, m.start, false, null));
      }
      final start = m.start, end = m.end;
      final recognizer = TapGestureRecognizer()
        ..onTap = () => widget.selection.toggle(_PickedWord(
              widget.sentenceId,
              widget.text,
              start,
              end,
              widget.wordLang,
              widget.meaningLang,
            ));
      tokens.add(_Token(m.group(0)!, start, end, true, recognizer));
      last = m.end;
    }
    if (last < text.length) {
      tokens.add(_Token(text.substring(last), last, text.length, false, null));
    }
    _tokens = tokens;
    _builtFor = text;
  }

  @override
  void dispose() {
    _disposeRecognizers();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_builtFor != widget.text) _tokenize();
    return ListenableBuilder(
      listenable: widget.selection,
      builder: (context, _) {
        return Text.rich(
          TextSpan(
            children: [
              for (final t in _tokens)
                if (!t.isWord)
                  TextSpan(text: t.text)
                else
                  TextSpan(
                    text: t.text,
                    recognizer: t.recognizer,
                    style: widget.selection.isSelected(widget.sentenceId, t.start)
                        ? const TextStyle(
                            backgroundColor: AppTheme.coralTint,
                            color: AppTheme.coral,
                            fontWeight: FontWeight.w900,
                          )
                        : TextStyle(
                            decoration: TextDecoration.underline,
                            decorationStyle: TextDecorationStyle.dotted,
                            decorationColor: AppTheme.moss.withValues(alpha: .35),
                          ),
                  ),
            ],
          ),
          style: widget.style,
          maxLines: widget.maxLines,
          overflow: widget.overflow,
        );
      },
    );
  }
}

/// Thanh "chốt" hiện khi đã chọn ít nhất 1 từ: Bỏ chọn / Lưu vào sổ tay.
/// Đặt vào `Scaffold.bottomNavigationBar`.
class WordSelectionBar extends StatelessWidget {
  final WordSelection selection;
  const WordSelectionBar({super.key, required this.selection});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: selection,
      builder: (context, _) {
        if (selection.isEmpty) return const SizedBox.shrink();
        final phrases = selection.phrases();
        final label = phrases.length == 1
            ? 'Đã chọn: ${phrases.first.text}'
            : 'Đã chọn ${phrases.length} mục';
        return Material(
          color: AppTheme.ivory,
          elevation: 8,
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 12, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                  TextButton(
                    onPressed: selection.clear,
                    child: const Text('Bỏ chọn'),
                  ),
                  const SizedBox(width: 4),
                  FilledButton(
                    // Theme app đặt minimumSize rộng vô hạn -> trong Row sẽ lỗi layout
                    // và thanh chốt không hiện. Ghi đè lại chiều rộng tối thiểu.
                    style: FilledButton.styleFrom(minimumSize: const Size(0, 44)),
                    onPressed: () => saveSelectedWords(context, selection),
                    child: const Text('Lưu vào sổ tay'),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Lưu các mục đã chọn: mỗi mục (từ hoặc cụm) mở 1 bảng "Thêm từ" giống bên Sổ
/// tay — đã điền sẵn từ/cụm, hai ngôn ngữ, và tự gợi ý nghĩa nếu có gói.
Future<void> saveSelectedWords(BuildContext context, WordSelection selection) async {
  final phrases = selection.phrases();
  if (phrases.isEmpty) return;
  final service = VocabularyService();
  var saved = 0;
  var cancelled = false;
  Object? lastError;

  for (var i = 0; i < phrases.length; i++) {
    final p = phrases[i];
    final many = phrases.length > 1;
    final result = await showDialog<NewWord>(
      context: context,
      builder: (_) => AddWordDialog(
        title: many ? 'Thêm từ (${i + 1}/${phrases.length})' : 'Thêm từ mới',
        initialWord: p.text,
        initialFromCode: p.wordLang,
        initialToCode: p.meaningLang,
        autoSuggest: true,
        skipLabel: many && i < phrases.length - 1 ? 'Bỏ qua' : null,
      ),
    );
    if (result == null) {
      cancelled = true; // Hủy -> dừng cả loạt
      break;
    }
    if (result.skipped) continue;
    try {
      await service.saveVocabulary(
        word: result.word,
        meaning: result.meaning,
        sourceLanguage: result.sourceCode,
        targetLanguage: result.targetCode,
        source: 'conversation',
      );
      saved++;
    } catch (e) {
      lastError = e;
    }
    if (!context.mounted) return;
  }

  if (!cancelled && saved > 0) selection.clear();
  if (!context.mounted || (saved == 0 && lastError == null)) return;
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
    content: Text(lastError == null
        ? 'Đã lưu $saved mục vào sổ tay'
        : 'Đã lưu $saved mục. Lỗi: $lastError'),
  ));
}
