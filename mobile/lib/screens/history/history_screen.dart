import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/theme.dart';
import '../../models/history.dart';
import '../../models/language.dart';
import '../../services/history_service.dart';
import '../../services/language_service.dart';
import '../../widgets/connection_banner.dart';
import '../../widgets/word_tools.dart';
import '../translate/conversation_detail_screen.dart';

/// Tab Lịch sử: toàn bộ bản dịch và các phiên dịch bằng giọng nói.
/// (Trước đây là mục "Gần đây" nằm trong tab Dịch.)
///
/// - Mỗi câu có nút sao chép riêng.
/// - Chạm 1 hoặc nhiều từ để chọn, rồi bấm "Lưu vào sổ tay" ở thanh dưới để chốt.
/// - Phiên nói có nút "Tóm tắt" mở màn chi tiết (các lượt nói, tóm tắt AI, xóa).
/// - Tự cập nhật khi tab Dịch lưu thêm bản dịch mới.
class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final _historyService = HistoryService();
  final _selection = WordSelection(); // các từ đang chọn để lưu vào sổ tay
  final _languageService = LanguageService();
  List<LanguageModel> _languages = [];

  List<TranslationHistoryItem> _items = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    HistoryService.changes.addListener(_reloadFromDevice);
    _load();
    _languageService.getLanguages().then((langs) {
      if (mounted) setState(() => _languages = langs);
    });
  }

  @override
  void dispose() {
    HistoryService.changes.removeListener(_reloadFromDevice);
    _selection.dispose();
    super.dispose();
  }

  /// Hiện ngay dữ liệu trên máy, rồi đồng bộ với máy chủ (nếu đã đăng nhập).
  Future<void> _load() async {
    await _reloadFromDevice();
    try {
      final items = await _historyService.getMyHistory();
      if (!mounted) return;
      setState(() {
        _items = items;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _reloadFromDevice() async {
    final cached = await _historyService.getCachedHistory();
    if (!mounted) return;
    setState(() {
      _items = cached;
      _loading = false;
    });
  }

  String _langName(String code) {
    for (final l in _languages) {
      if (l.code == code) return l.name;
    }
    return code;
  }

  Future<void> _openConversation(TranslationHistoryItem item) async {
    final deleted = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => ConversationDetailScreen(
          item: item,
          sourceName: _langName(item.sourceLanguage),
          targetName: _langName(item.targetLanguage),
        ),
      ),
    );
    if (!mounted) return;
    if (deleted == true) {
      setState(() => _items.removeWhere((r) => r.id == item.id));
    }
    _reloadFromDevice(); // lấy bản tóm tắt vừa tạo (nếu có)
  }

  Future<void> _copy(String text, String what) async {
    if (text.trim().isEmpty) return;
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text('Đã sao chép $what')));
  }

  Future<void> _clearAll() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xóa toàn bộ lịch sử?'),
        content: const Text('Tất cả bản dịch và cuộc trò chuyện sẽ bị xóa.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(minimumSize: const Size(0, 44)),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Xóa tất cả'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    final items = List<TranslationHistoryItem>.from(_items);
    setState(() => _items = []);
    for (final item in items) {
      try {
        await _historyService.deleteHistory(item.id);
      } catch (_) {
        // best effort — mục xóa lỗi sẽ quay lại ở lần tải sau
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Lịch sử'),
        actions: [
          if (_items.isNotEmpty)
            TextButton(onPressed: _clearAll, child: const Text('Xóa tất cả')),
        ],
      ),
      bottomNavigationBar: WordSelectionBar(selection: _selection),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(
            AppTheme.spaceMd, 8, AppTheme.spaceMd, 32,
          ),
          children: [
            const ConnectionBanner(),
            if (_loading)
              const Padding(
                padding: EdgeInsets.all(40),
                child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
              )
            else if (_items.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 60),
                child: Center(
                  child: Text(
                    'Chưa có bản dịch nào.\nDịch một câu ở tab Dịch để bắt đầu nhé.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppTheme.moss.withValues(alpha: .5),
                      fontSize: 13.5,
                      height: 1.5,
                    ),
                  ),
                ),
              )
            else
              ..._items.map(_buildCard),
          ],
        ),
      ),
    );
  }

  String _hms(DateTime d) {
    final l = d.toLocal();
    String p2(int n) => n.toString().padLeft(2, '0');
    return '${p2(l.hour)}:${p2(l.minute)}:${p2(l.second)}';
  }

  /// 1 câu: chữ chạm được (thêm vào từ vựng) + nút sao chép riêng cho câu đó.
  Widget _sentence({
    required String text,
    required String what,
    required String wordLang,
    required String meaningLang,
    Color? color,
    int? maxLines,
    double top = 8,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Padding(
            padding: EdgeInsets.only(top: top),
            child: TappableWords(
              text: text,
              maxLines: maxLines,
              overflow: maxLines == null ? null : TextOverflow.ellipsis,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 14,
                color: color,
              ),
              selection: _selection,
              wordLang: wordLang,
              meaningLang: meaningLang,
            ),
          ),
        ),
        IconButton(
          tooltip: 'Sao chép $what',
          visualDensity: VisualDensity.compact,
          icon: const Icon(Icons.copy_rounded, size: 18),
          color: AppTheme.moss.withValues(alpha: .6),
          onPressed: () => _copy(text, what),
        ),
      ],
    );
  }

  Widget _buildCard(TranslationHistoryItem item) {
    final dir =
        '${item.sourceLanguage.toUpperCase()} → ${item.targetLanguage.toUpperCase()}';
    final now = DateTime.now();
    final created = item.createdAt.toLocal();
    final sameDay = created.year == now.year &&
        created.month == now.month &&
        created.day == now.day;
    final time = sameDay
        ? '${created.hour}:${created.minute.toString().padLeft(2, '0')}'
        : '${created.day.toString().padLeft(2, '0')}/${created.month.toString().padLeft(2, '0')}';
    final isConversation = item.type == 'conversation' && item.segments.isNotEmpty;
    // Phiên nói: sao chép toàn bộ các lượt nói, mỗi lượt 1 dòng.
    final source = isConversation
        ? item.segments.map((s) => s.sourceText).join('\n')
        : item.sourceText;
    final target = isConversation
        ? item.segments.map((s) => s.translatedText).join('\n')
        : item.translatedText;

    Widget pill(String text, Color bg, Color fg) => Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 2),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            text,
            style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: fg),
          ),
        );

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.fromLTRB(15, 12, 6, 8),
      decoration: BoxDecoration(
        color: AppTheme.ivory,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              pill(dir, const Color(0xFFDCEFE2), const Color(0xFF1C7A45)),
              if (isConversation) ...[
                const SizedBox(width: 6),
                pill(
                  '${item.segments.length} lượt nói',
                  AppTheme.sand,
                  AppTheme.moss.withValues(alpha: .6),
                ),
              ],
              const SizedBox(width: 8),
              Text(
                time,
                style: TextStyle(
                  fontSize: 11.5,
                  color: AppTheme.moss.withValues(alpha: .45),
                ),
              ),
            ],
          ),
          if (isConversation) ...[
            // Tóm gọn: chỉ 1 dòng xem trước + số lượt. Muốn xem chi tiết từng
            // lượt (giờ, copy, lưu từ, xóa riêng) thì bấm "Chi tiết".
            Padding(
              padding: const EdgeInsets.only(top: 8, right: 9),
              child: Text(
                '${_hms(item.segments.first.at)}  ${item.segments.first.sourceText}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
              ),
            ),
            Row(
              children: [
                TextButton.icon(
                  onPressed: () => _copy(source, 'toàn bộ câu nguồn'),
                  icon: const Icon(Icons.copy_rounded, size: 16),
                  label: const Text('Chép nguồn'),
                ),
                TextButton.icon(
                  onPressed: () => _copy(target, 'toàn bộ câu đích'),
                  icon: const Icon(Icons.copy_rounded, size: 16),
                  label: const Text('Chép đích'),
                ),
              ],
            ),
          ] else ...[
            _sentence(
              text: source,
              what: 'câu nguồn',
              wordLang: item.sourceLanguage,
              meaningLang: item.targetLanguage,
            ),
            _sentence(
              text: target,
              what: 'câu đích',
              wordLang: item.targetLanguage,
              meaningLang: item.sourceLanguage,
              color: AppTheme.moss,
              top: 0,
            ),
          ],
          if (isConversation)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () => _openConversation(item),
                icon: const Icon(Icons.chevron_right_rounded, size: 18),
                label: Text(
                  (item.summary ?? '').trim().isNotEmpty
                      ? 'Chi tiết · có tóm tắt'
                      : 'Chi tiết & tóm tắt',
                ),
              ),
            ),
        ],
      ),
    );
  }
}
