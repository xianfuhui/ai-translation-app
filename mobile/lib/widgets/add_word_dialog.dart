import 'package:flutter/material.dart';
import '../models/language.dart';
import '../services/language_service.dart';
import '../services/translation_service.dart';

/// Kết quả của bảng "Thêm từ".
class NewWord {
  final String word;
  final String meaning;
  final String sourceCode; // ngôn ngữ của từ
  final String targetCode; // ngôn ngữ của nghĩa
  final bool skipped; // người dùng bấm "Bỏ qua" (khi lưu nhiều mục liên tiếp)

  const NewWord(this.word, this.meaning, this.sourceCode, this.targetCode)
      : skipped = false;
  const NewWord.skip()
      : word = '',
        meaning = '',
        sourceCode = '',
        targetCode = '',
        skipped = true;
}

/// Bảng "Thêm từ" dùng chung: tab Sổ tay (tự tạo từ) và tab Lịch sử (lưu từ /
/// cụm từ đã chọn). Cùng một giao diện: Từ, ngôn ngữ của từ, ngôn ngữ của nghĩa,
/// Nghĩa (kèm nút ✨ gợi ý bằng ML Kit).
class AddWordDialog extends StatefulWidget {
  final String title;
  final String? initialWord;
  final String? initialFromCode;
  final String? initialToCode;

  /// Tự gợi ý nghĩa ngay khi mở (chỉ khi hai gói ngôn ngữ đã tải).
  final bool autoSuggest;

  /// Có chữ -> hiện thêm nút "Bỏ qua" (dùng khi lưu nhiều mục liên tiếp).
  final String? skipLabel;

  const AddWordDialog({
    super.key,
    this.title = 'Thêm từ mới',
    this.initialWord,
    this.initialFromCode,
    this.initialToCode,
    this.autoSuggest = false,
    this.skipLabel,
  });

  @override
  State<AddWordDialog> createState() => _AddWordDialogState();
}

class _AddWordDialogState extends State<AddWordDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _word =
      TextEditingController(text: widget.initialWord ?? '');
  final _meaning = TextEditingController();
  final _translation = TranslationService();

  List<LanguageModel> _languages = [];
  LanguageModel? _from; // ngôn ngữ của từ
  LanguageModel? _to; // ngôn ngữ của nghĩa
  bool _suggesting = false;
  String? _hint;

  @override
  void initState() {
    super.initState();
    LanguageService().getLanguages().then((langs) {
      if (!mounted || langs.isEmpty) return;
      LanguageModel? byCode(String? code) {
        if (code == null) return null;
        for (final l in langs) {
          if (l.code == code) return l;
        }
        return null;
      }

      setState(() {
        _languages = langs;
        _from = byCode(widget.initialFromCode) ?? langs.first;
        _to = byCode(widget.initialToCode) ??
            (langs.length > 1 ? langs[1] : langs.first);
      });
      if (widget.autoSuggest) _suggest(silent: true);
    });
  }

  @override
  void dispose() {
    _word.dispose();
    _meaning.dispose();
    _translation.dispose();
    super.dispose();
  }

  /// Gợi ý nghĩa bằng ML Kit (ngoại tuyến). Không tự tải gói — chỉ dùng nếu
  /// hai gói ngôn ngữ đã có trên máy.
  Future<void> _suggest({bool silent = false}) async {
    final word = _word.text.trim();
    final from = _from, to = _to;
    if (word.isEmpty || from == null || to == null) return;
    if (from.code == to.code) {
      if (!silent) setState(() => _hint = 'Hai ngôn ngữ đang giống nhau.');
      return;
    }
    setState(() {
      _suggesting = true;
      _hint = null;
    });
    try {
      final ready = _translation.isSupported(from.code) &&
          _translation.isSupported(to.code) &&
          await _translation.isModelDownloaded(from.code) &&
          await _translation.isModelDownloaded(to.code);
      if (!ready) {
        if (mounted && !silent) {
          setState(() => _hint =
              'Cần tải gói ngôn ngữ trước (Cá nhân → Gói ngoại tuyến) mới gợi ý được.');
        }
        return;
      }
      final result = await _translation.translate(
        text: word,
        sourceCode: from.code,
        targetCode: to.code,
      );
      if (mounted && (!silent || _meaning.text.isEmpty)) _meaning.text = result;
    } catch (e) {
      if (mounted && !silent) setState(() => _hint = 'Không gợi ý được: $e');
    } finally {
      if (mounted) setState(() => _suggesting = false);
    }
  }

  Widget _langPicker(
    String label,
    LanguageModel? value,
    ValueChanged<LanguageModel?> onChanged,
  ) {
    return DropdownButtonFormField<LanguageModel>(
      // key đổi theo giá trị -> ô chọn cập nhật khi danh sách ngôn ngữ tải xong.
      key: ValueKey('$label|${value?.code}|${_languages.length}'),
      initialValue: value,
      isExpanded: true,
      decoration: InputDecoration(labelText: label),
      items: [
        for (final l in _languages)
          DropdownMenuItem(
            value: l,
            child: Text(l.name, overflow: TextOverflow.ellipsis),
          ),
      ],
      onChanged: onChanged,
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _word,
                autofocus: widget.initialWord == null,
                decoration: const InputDecoration(labelText: 'Từ *'),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Vui lòng nhập từ' : null,
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: _langPicker(
                      'Ngôn ngữ của từ',
                      _from,
                      (v) => setState(() => _from = v),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _langPicker(
                      'Ngôn ngữ của nghĩa',
                      _to,
                      (v) => setState(() => _to = v),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _meaning,
                decoration: InputDecoration(
                  labelText: 'Nghĩa của từ *',
                  suffixIcon: _suggesting
                      ? const Padding(
                          padding: EdgeInsets.all(14),
                          child: SizedBox(
                            height: 14,
                            width: 14,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        )
                      : IconButton(
                          tooltip: 'Gợi ý nghĩa',
                          icon: const Icon(Icons.auto_awesome_rounded, size: 20),
                          onPressed: _suggest,
                        ),
                ),
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? 'Vui lòng nhập nghĩa của từ'
                    : null,
              ),
              if (_hint != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(_hint!, style: const TextStyle(fontSize: 12)),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Hủy'),
        ),
        if (widget.skipLabel != null)
          TextButton(
            onPressed: () => Navigator.pop(context, const NewWord.skip()),
            child: Text(widget.skipLabel!),
          ),
        FilledButton(
          style: FilledButton.styleFrom(minimumSize: const Size(0, 44)),
          onPressed: () {
            if (!_formKey.currentState!.validate()) return;
            final from = _from, to = _to;
            Navigator.pop(
              context,
              NewWord(
                _word.text.trim(),
                _meaning.text.trim(),
                from?.code ?? widget.initialFromCode ?? '',
                to?.code ?? widget.initialToCode ?? '',
              ),
            );
          },
          child: const Text('Lưu vào sổ tay'),
        ),
      ],
    );
  }
}
