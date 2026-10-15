import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import '../core/theme.dart';
import '../services/translation_service.dart';
import '../services/vocabulary_service.dart';

/// Từ = chuỗi chữ/số Unicode (cho phép ' và - ở giữa từ, vd "don't", "well-known").
/// Chữ CJK không có dấu cách nên cả cụm liền nhau được tính là 1 "từ".
final RegExp _wordPattern =
    RegExp(r"[\p{L}\p{N}][\p{L}\p{N}'’\-]*", unicode: true);

/// Một từ người dùng đã chọn (kèm ngôn ngữ của từ và của nghĩa).
class SelectedWord {
  final String word;
  final String wordLang;
  final String meaningLang;
  const SelectedWord(this.word, this.wordLang, this.meaningLang);
}

/// Tập các từ đang được chọn trên 1 màn hình. Chạm từ = chọn / bỏ chọn;
/// chỉ khi bấm "Lưu vào sổ tay" ở thanh chốt thì mới lưu.
class WordSelection extends ChangeNotifier {
  final Map<String, SelectedWord> _items = {};

  String _key(String word, String lang) => '$lang|${word.toLowerCase()}';

  bool get isEmpty => _items.isEmpty;
  int get count => _items.length;
  List<SelectedWord> get items => _items.values.toList();

  bool contains(String word, String lang) => _items.containsKey(_key(word, lang));

  void toggle(String word, String wordLang, String meaningLang) {
    final k = _key(word, wordLang);
    if (_items.remove(k) == null) {
      _items[k] = SelectedWord(word, wordLang, meaningLang);
    }
    notifyListeners();
  }

  void clear() {
    if (_items.isEmpty) return;
    _items.clear();
    notifyListeners();
  }
}

class _Token {
  final String text;
  final bool isWord;
  final TapGestureRecognizer? recognizer;
  const _Token(this.text, this.isWord, this.recognizer);
}

/// Đoạn chữ mà từng từ chạm được để CHỌN (tô nền khi đã chọn). Chọn 1 hoặc
/// nhiều từ, rồi bấm nút chốt ở [WordSelectionBar] để lưu vào sổ tay.
class TappableWords extends StatefulWidget {
  final String text;
  final TextStyle? style;
  final int? maxLines;
  final TextOverflow? overflow;
  final WordSelection selection;
  final String wordLang; // ngôn ngữ của đoạn chữ này
  final String meaningLang; // ngôn ngữ dùng để ghi nghĩa

  const TappableWords({
    super.key,
    required this.text,
    required this.selection,
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
      if (m.start > last) tokens.add(_Token(text.substring(last, m.start), false, null));
      final word = m.group(0)!;
      final recognizer = TapGestureRecognizer()
        ..onTap = () => widget.selection.toggle(word, widget.wordLang, widget.meaningLang);
      tokens.add(_Token(word, true, recognizer));
      last = m.end;
    }
    if (last < text.length) tokens.add(_Token(text.substring(last), false, null));
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
                    style: widget.selection.contains(t.text, widget.wordLang)
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
                      'Đã chọn ${selection.count} từ',
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

/// Mở hộp thoại ghi nghĩa cho các từ đã chọn rồi lưu hết vào sổ tay.
Future<void> saveSelectedWords(BuildContext context, WordSelection selection) async {
  final picked = selection.items;
  if (picked.isEmpty) return;
  final meanings = await showDialog<List<String>>(
    context: context,
    builder: (_) => _SaveWordsDialog(words: picked),
  );
  if (meanings == null) return;

  final service = VocabularyService();
  var saved = 0;
  Object? lastError;
  for (var i = 0; i < picked.length; i++) {
    try {
      await service.saveVocabulary(
        word: picked[i].word,
        meaning: meanings[i],
        sourceLanguage: picked[i].wordLang,
        targetLanguage: picked[i].meaningLang,
        source: 'conversation',
      );
      saved++;
    } catch (e) {
      lastError = e;
    }
  }
  if (saved > 0) selection.clear();
  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
    content: Text(lastError == null
        ? 'Đã lưu $saved từ vào sổ tay'
        : 'Đã lưu $saved/${picked.length} từ. Lỗi: $lastError'),
  ));
}

class _SaveWordsDialog extends StatefulWidget {
  final List<SelectedWord> words;
  const _SaveWordsDialog({required this.words});

  @override
  State<_SaveWordsDialog> createState() => _SaveWordsDialogState();
}

class _SaveWordsDialogState extends State<_SaveWordsDialog> {
  final _formKey = GlobalKey<FormState>();
  final _translation = TranslationService();
  late final List<TextEditingController> _controllers = [
    for (final _ in widget.words) TextEditingController(),
  ];
  bool _suggesting = true;

  @override
  void initState() {
    super.initState();
    _suggestAll();
  }

  /// Gợi ý nghĩa bằng ML Kit nếu hai gói ngôn ngữ đã tải (không tự tải).
  Future<void> _suggestAll() async {
    for (var i = 0; i < widget.words.length; i++) {
      final w = widget.words[i];
      try {
        final ok = w.wordLang != w.meaningLang &&
            _translation.isSupported(w.wordLang) &&
            _translation.isSupported(w.meaningLang) &&
            await _translation.isModelDownloaded(w.wordLang) &&
            await _translation.isModelDownloaded(w.meaningLang);
        if (!ok) continue;
        final result = await _translation.translate(
          text: w.word,
          sourceCode: w.wordLang,
          targetCode: w.meaningLang,
        );
        if (!mounted) return;
        if (_controllers[i].text.isEmpty) _controllers[i].text = result;
      } catch (_) {
        // không gợi ý được -> người dùng tự nhập
      }
    }
    if (mounted) setState(() => _suggesting = false);
  }

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    _translation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Lưu ${widget.words.length} từ vào sổ tay'),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_suggesting)
                  const Padding(
                    padding: EdgeInsets.only(bottom: 8),
                    child: LinearProgressIndicator(minHeight: 2),
                  ),
                for (var i = 0; i < widget.words.length; i++)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: TextFormField(
                      controller: _controllers[i],
                      decoration: InputDecoration(
                        labelText: 'Nghĩa của "${widget.words[i].word}" *',
                      ),
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? 'Vui lòng nhập nghĩa'
                          : null,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Hủy'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(minimumSize: const Size(0, 44)),
          onPressed: () {
            if (!_formKey.currentState!.validate()) return;
            Navigator.pop(context, [for (final c in _controllers) c.text.trim()]);
          },
          child: const Text('Lưu tất cả'),
        ),
      ],
    );
  }
}
