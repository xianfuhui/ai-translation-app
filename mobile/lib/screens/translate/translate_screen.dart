import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import '../../models/language.dart';
import '../../services/language_service.dart';
import '../../services/history_service.dart';
import '../../services/vocabulary_service.dart';

/// Màn hình Dịch ngôn ngữ.
///
/// LƯU Ý VỀ OFFLINE:
/// - Danh sách ngôn ngữ tải 1 lần từ backend rồi cache lại để dùng offline.
/// - Speech-to-Text dùng gói `vosk_flutter` (model tải sẵn về máy - xem README
///   phần "Tích hợp Vosk" để biết cách nạp model theo `voskModelName`).
/// - Text-to-Speech dùng `flutter_tts` (dùng engine TTS hệ thống, tương đương
///   mục tiêu của ML Kit trên Android).
/// - Bản thân việc DỊCH văn bản cần một engine dịch offline (vd model dịch máy
///   nhúng theo `translationModel` của từng Language). Hàm `_translate()` bên
///   dưới là điểm nối (interface) để bạn cắm engine dịch thật vào.
class TranslateScreen extends StatefulWidget {
  const TranslateScreen({super.key});

  @override
  State<TranslateScreen> createState() => _TranslateScreenState();
}

class _TranslateScreenState extends State<TranslateScreen> {
  final _languageService = LanguageService();
  final _historyService = HistoryService();
  final _vocabularyService = VocabularyService();
  final _tts = FlutterTts();
  final _inputController = TextEditingController();

  List<LanguageModel> _languages = [];
  LanguageModel? _sourceLang;
  LanguageModel? _targetLang;
  String _translatedText = '';
  bool _loadingLanguages = true;
  bool _isTranslating = false;
  bool _isListening = false;

  @override
  void initState() {
    super.initState();
    _loadLanguages();
  }

  Future<void> _loadLanguages() async {
    try {
      final langs = await _languageService.getLanguages();
      setState(() {
        _languages = langs;
        if (langs.isNotEmpty) {
          _sourceLang = langs.first;
          _targetLang = langs.length > 1 ? langs[1] : langs.first;
        }
        _loadingLanguages = false;
      });
    } catch (e) {
      setState(() => _loadingLanguages = false);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Không tải được danh sách ngôn ngữ: $e')),
      );
    }
  }

  void _swapLanguages() {
    setState(() {
      final tmp = _sourceLang;
      _sourceLang = _targetLang;
      _targetLang = tmp;
    });
  }

  // TODO: Thay bằng lời gọi engine dịch offline thật (theo `_sourceLang.translationModel`).
  Future<String> _translate(String text) async {
    await Future.delayed(const Duration(milliseconds: 400));
    return '[Bản dịch offline sẽ hiện ở đây] $text';
  }

  Future<void> _handleTranslate() async {
    final text = _inputController.text.trim();
    if (text.isEmpty || _sourceLang == null || _targetLang == null) return;

    setState(() => _isTranslating = true);
    try {
      final result = await _translate(text);
      setState(() => _translatedText = result);

      // Lưu lịch sử (Online - best effort, không chặn UI nếu lỗi mạng)
      _historyService
          .createHistory(
            sourceLanguage: _sourceLang!.code,
            targetLanguage: _targetLang!.code,
            sourceText: text,
            translatedText: result,
            type: 'text',
          )
          .catchError((_) {});
    } finally {
      if (mounted) setState(() => _isTranslating = false);
    }
  }

  Future<void> _speak(String text, String? langCode) async {
    if (text.isEmpty) return;
    if (langCode != null) await _tts.setLanguage(langCode);
    await _tts.speak(text);
  }

  // TODO: Nối với vosk_flutter: khởi tạo recognizer bằng model theo
  // `_sourceLang.voskModelName`, lắng nghe audio stream, đổ kết quả vào _inputController.
  Future<void> _toggleListening() async {
    setState(() => _isListening = !_isListening);
    if (!_isListening) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Đang lắng nghe... (tích hợp Vosk tại đây)')),
    );
  }

  Future<void> _saveWordAsVocabulary(String word) async {
    try {
      await _vocabularyService.saveVocabulary(
        word: word,
        sourceLanguage: _sourceLang?.code,
        targetLanguage: _targetLang?.code,
        source: 'conversation',
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Đã lưu "$word" vào từ vựng yêu thích')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Lưu từ vựng thất bại: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loadingLanguages) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Dịch ngôn ngữ')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              _buildLanguageSelector(),
              const SizedBox(height: 16),
              _buildInputCard(),
              const SizedBox(height: 16),
              if (_translatedText.isNotEmpty) _buildResultCard(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLanguageSelector() {
    return Row(
      children: [
        Expanded(child: _languageDropdown(_sourceLang, (v) => setState(() => _sourceLang = v))),
        IconButton(icon: const Icon(Icons.swap_horiz), onPressed: _swapLanguages),
        Expanded(child: _languageDropdown(_targetLang, (v) => setState(() => _targetLang = v))),
      ],
    );
  }

  Widget _languageDropdown(LanguageModel? value, ValueChanged<LanguageModel?> onChanged) {
    return DropdownButtonFormField<LanguageModel>(
      value: value,
      isExpanded: true,
      decoration: const InputDecoration(border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 12)),
      items: _languages.map((l) => DropdownMenuItem(value: l, child: Text(l.name, overflow: TextOverflow.ellipsis))).toList(),
      onChanged: onChanged,
    );
  }

  Widget _buildInputCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _inputController,
              maxLines: 4,
              decoration: const InputDecoration(hintText: 'Nhập văn bản cần dịch...', border: InputBorder.none),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                IconButton(
                  icon: Icon(_isListening ? Icons.mic : Icons.mic_none),
                  color: _isListening ? Colors.red : null,
                  onPressed: _toggleListening,
                  tooltip: 'Chuyển giọng nói thành văn bản',
                ),
                const SizedBox(width: 8),
                FilledButton.icon(
                  onPressed: _isTranslating ? null : _handleTranslate,
                  icon: _isTranslating
                      ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.translate, size: 18),
                  label: const Text('Dịch'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResultCard() {
    final words = _translatedText.split(RegExp(r'\s+'));
    return Expanded(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Kết quả', style: TextStyle(fontWeight: FontWeight.w600)),
                  IconButton(
                    icon: const Icon(Icons.volume_up_outlined),
                    onPressed: () => _speak(_translatedText, _targetLang?.code),
                    tooltip: 'Chuyển văn bản thành giọng nói',
                  ),
                ],
              ),
              const Divider(),
              Expanded(
                child: SingleChildScrollView(
                  child: Wrap(
                    spacing: 4,
                    runSpacing: 4,
                    children: words
                        .map((w) => ActionChip(
                              label: Text(w),
                              onPressed: () => _saveWordAsVocabulary(w.replaceAll(RegExp(r'[^\wÀ-ỹ]'), '')),
                            ))
                        .toList(),
                  ),
                ),
              ),
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text(
                  'Chạm vào 1 từ để lưu vào từ vựng yêu thích',
                  style: TextStyle(fontSize: 11, color: Colors.grey),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
