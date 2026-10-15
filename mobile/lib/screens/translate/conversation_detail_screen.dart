import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_tts/flutter_tts.dart';
import '../../core/api_exception.dart';
import '../../core/backend_status.dart';
import '../../core/local_store.dart';
import '../../core/session.dart';
import '../../core/sync_queue.dart';
import '../../core/theme.dart';
import '../../models/history.dart';
import '../../services/history_service.dart';
import '../../widgets/word_tools.dart';

/// Detail of one live voice-translation session (a "conversation" history
/// entry): every spoken turn with its time, the session's start / end /
/// duration, and an AI summary button.
///
/// Viewing works fully offline (the session is stored on the device). The
/// summary needs the backend + LLM, so it is only available when signed in
/// and online; a summary that was already generated is kept and shown offline.
///
/// Pops with `true` when the entry was deleted.
class ConversationDetailScreen extends StatefulWidget {
  final TranslationHistoryItem item;
  final String sourceName;
  final String targetName;

  const ConversationDetailScreen({
    super.key,
    required this.item,
    required this.sourceName,
    required this.targetName,
  });

  @override
  State<ConversationDetailScreen> createState() => _ConversationDetailScreenState();
}

class _ConversationDetailScreenState extends State<ConversationDetailScreen> {
  final _history = HistoryService();
  final _tts = FlutterTts();
  final _selection = WordSelection(); // các từ đang chọn để lưu vào sổ tay

  // Bản sao các lượt nói để xóa từng lượt mà không cần dựng lại màn hình cha.
  late List<HistorySegment> _segments = List.of(widget.item.segments);
  // Lượt nào đang mở chi tiết (mặc định thu gọn). Khóa = mili-giây của lượt.
  final Set<int> _expanded = {};

  String? _summary;
  bool _summarizing = false;
  String? _summaryError;

  @override
  void initState() {
    super.initState();
    final existing = widget.item.summary;
    _summary = (existing != null && existing.trim().isNotEmpty) ? existing : null;
  }

  @override
  void dispose() {
    _tts.stop();
    _selection.dispose();
    super.dispose();
  }

  // ===== Actions =====

  Future<void> _summarize() async {
    setState(() {
      _summarizing = true;
      _summaryError = null;
    });
    try {
      BackendStatus.reset(); // explicit user action may retry the network
      final queue = SyncQueue();
      await queue.flush(); // upload this session first if it was saved offline
      final id = await queue.resolveId(widget.item.id);
      if (isLocalId(id)) {
        throw ApiException(
          'Hội thoại này chưa được đồng bộ lên máy chủ. Hãy kết nối mạng rồi thử lại.',
        );
      }
      final summary = await _history.summarizeHistory(id);
      if (!mounted) return;
      setState(() => _summary = summary.trim().isEmpty ? null : summary);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        if (e is NetworkException) {
          _summaryError = e.guest
              ? e.message
              : 'Cần kết nối mạng để tóm tắt. Bạn vẫn xem được toàn bộ nội dung ngoại tuyến.';
        } else {
          _summaryError = 'Tóm tắt thất bại: $e';
        }
      });
    } finally {
      if (mounted) setState(() => _summarizing = false);
    }
  }

  Future<void> _speak(HistorySegment segment) async {
    await _tts.stop();
    await _tts.setLanguage(widget.item.targetLanguage);
    await _tts.speak(segment.translatedText);
  }

  Future<void> _copyTranscript() async {
    final buffer = StringBuffer();
    for (final s in _segments) {
      buffer.writeln('[${_hms(s.at)}] ${s.sourceText}');
      buffer.writeln('→ ${s.translatedText}');
      buffer.writeln();
    }
    if (_summary != null) buffer.writeln('Tóm tắt: $_summary');
    await Clipboard.setData(ClipboardData(text: buffer.toString().trim()));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Đã sao chép nội dung hội thoại')),
    );
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xóa hội thoại này?'),
        content: const Text('Toàn bộ các lượt nói và bản tóm tắt sẽ bị xóa.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(minimumSize: const Size(0, 44)),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Xóa'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await _history.deleteHistory(widget.item.id);
    if (mounted) Navigator.pop(context, true);
  }

  Future<void> _deleteSegment(HistorySegment seg) async {
    final isLast = _segments.length == 1;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xóa lượt nói này?'),
        content: Text(
          isLast
              ? 'Đây là lượt nói cuối cùng nên cả hội thoại sẽ bị xóa.'
              : '"${seg.sourceText}"',
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(minimumSize: const Size(0, 44)),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Xóa'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      final wholeDeleted = await _history.deleteSegment(widget.item.id, seg.at);
      if (!mounted) return;
      if (wholeDeleted) {
        Navigator.pop(context, true);
        return;
      }
      setState(() {
        _segments.removeWhere(
          (s) => s.at.millisecondsSinceEpoch == seg.at.millisecondsSinceEpoch,
        );
        _expanded.remove(seg.at.millisecondsSinceEpoch);
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Không xóa được lượt nói: $e')));
    }
  }

  // ===== Formatting =====

  String _p2(int n) => n.toString().padLeft(2, '0');

  String _hms(DateTime d) {
    final l = d.toLocal();
    return '${_p2(l.hour)}:${_p2(l.minute)}:${_p2(l.second)}';
  }

  String _date(DateTime d) {
    final l = d.toLocal();
    return '${_p2(l.day)}/${_p2(l.month)}/${l.year}';
  }

  String _duration(Duration d) {
    if (d.inSeconds < 1) return 'dưới 1 giây';
    final h = d.inHours;
    final m = d.inMinutes % 60;
    final s = d.inSeconds % 60;
    if (h > 0) return '$h giờ $m phút';
    if (m > 0) return '$m phút $s giây';
    return '$s giây';
  }

  /// "+0:12" = how long after the session started this turn was recognised.
  String _offset(DateTime start, DateTime at) {
    var d = at.difference(start);
    if (d.isNegative) d = Duration.zero;
    return '+${d.inMinutes}:${_p2(d.inSeconds % 60)}';
  }

  // ===== UI =====

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final segments = _segments;
    final start = item.startedAt ?? (segments.isNotEmpty ? segments.first.at : item.createdAt);
    final end = item.endedAt ?? (segments.isNotEmpty ? segments.last.at : item.createdAt);

    return Scaffold(
      bottomNavigationBar: WordSelectionBar(selection: _selection),
      appBar: AppBar(
        title: const Text('Hội thoại'),
        actions: [
          IconButton(
            tooltip: 'Sao chép nội dung',
            icon: const Icon(Icons.copy_rounded),
            onPressed: segments.isEmpty ? null : _copyTranscript,
          ),
          IconButton(
            tooltip: 'Xóa hội thoại',
            icon: const Icon(Icons.delete_outline_rounded),
            onPressed: _delete,
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(AppTheme.spaceMd, 8, AppTheme.spaceMd, 32),
        children: [
          _buildHeader(item, start, end),
          const SizedBox(height: 16),
          _buildSummaryCard(),
          const SizedBox(height: 22),
          Text(
            'Các lượt nói (${segments.length})',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 4),
          Text(
            'Chạm một lượt để xem chi tiết. Trong chi tiết, chạm một hoặc nhiều từ rồi bấm "Lưu vào sổ tay".',
            style: TextStyle(fontSize: 12, color: AppTheme.moss.withValues(alpha: .5)),
          ),
          const SizedBox(height: 10),
          if (segments.isEmpty)
            Text(
              'Hội thoại này không có lượt nói nào.',
              style: TextStyle(color: AppTheme.moss.withValues(alpha: .55)),
            )
          else
            for (var i = 0; i < segments.length; i++) _buildSegment(i, segments[i], start),
        ],
      ),
    );
  }

  Widget _buildHeader(TranslationHistoryItem item, DateTime start, DateTime end) {
    final synced = !isLocalId(item.id);
    return Container(
      padding: const EdgeInsets.all(AppTheme.spaceLg),
      decoration: BoxDecoration(
        color: AppTheme.moss,
        borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${widget.sourceName} → ${widget.targetName}',
            style: const TextStyle(
              color: AppTheme.ivory,
              fontSize: 19,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _date(start),
            style: TextStyle(color: AppTheme.ivory.withValues(alpha: .72), fontSize: 13),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              _headerStat('Bắt đầu', _hms(start)),
              _headerStat('Kết thúc', _hms(end)),
              _headerStat('Thời lượng', _duration(end.difference(start))),
            ],
          ),
          if (!AppSession.isGuest && !synced) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(Icons.cloud_off_rounded,
                    size: 15, color: AppTheme.ivory.withValues(alpha: .72)),
                const SizedBox(width: 6),
                Text(
                  'Chưa đồng bộ lên máy chủ',
                  style: TextStyle(
                    color: AppTheme.ivory.withValues(alpha: .72),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _headerStat(String label, String value) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(color: AppTheme.ivory.withValues(alpha: .6), fontSize: 11.5),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: const TextStyle(
              color: AppTheme.ivory,
              fontSize: 14,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard() {
    final isGuest = AppSession.isGuest;
    return Container(
      padding: const EdgeInsets.all(AppTheme.spaceMd),
      decoration: BoxDecoration(
        color: AppTheme.coralTint,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.coral.withValues(alpha: .25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.auto_awesome_rounded, size: 18, color: AppTheme.coral),
              const SizedBox(width: 8),
              Text('Tóm tắt', style: Theme.of(context).textTheme.titleMedium),
            ],
          ),
          const SizedBox(height: 10),
          if (_summary != null)
            Text(_summary!, style: const TextStyle(fontSize: 14, height: 1.5))
          else
            Text(
              isGuest
                  ? 'Tóm tắt bằng AI cần tài khoản và kết nối mạng.'
                  : 'Chưa có bản tóm tắt. Bấm nút bên dưới khi có mạng để AI tóm tắt nội dung hội thoại.',
              style: TextStyle(
                fontSize: 13,
                height: 1.45,
                color: AppTheme.moss.withValues(alpha: .68),
              ),
            ),
          if (_summaryError != null) ...[
            const SizedBox(height: 8),
            Text(
              _summaryError!,
              style: const TextStyle(
                fontSize: 12.5,
                height: 1.4,
                color: AppTheme.cranberry,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
          const SizedBox(height: 12),
          ValueListenableBuilder<bool>(
            valueListenable: BackendStatus.online,
            builder: (context, online, _) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  FilledButton.icon(
                    onPressed: (isGuest || _summarizing || widget.item.segments.isEmpty)
                        ? null
                        : _summarize,
                    icon: _summarizing
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppTheme.ivory,
                            ),
                          )
                        : const Icon(Icons.auto_awesome_rounded, size: 18),
                    label: Text(_summary == null ? 'Tóm tắt hội thoại' : 'Tóm tắt lại'),
                  ),
                  if (!isGuest && !online) ...[
                    const SizedBox(height: 6),
                    Text(
                      'Đang ngoại tuyến — cần mạng để tóm tắt (vẫn có thể bấm thử lại).',
                      style: TextStyle(
                        fontSize: 11.5,
                        color: AppTheme.moss.withValues(alpha: .6),
                      ),
                    ),
                  ],
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  /// 1 câu của lượt nói: chữ chạm được (thêm vào từ vựng) + nút sao chép câu.
  Widget _sentenceRow({
    required String text,
    required String what,
    required String wordLang,
    required String meaningLang,
    required TextStyle style,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: TappableWords(
            text: text,
            style: style,
            selection: _selection,
            wordLang: wordLang,
            meaningLang: meaningLang,
          ),
        ),
        IconButton(
          tooltip: 'Sao chép $what',
          visualDensity: VisualDensity.compact,
          icon: const Icon(Icons.copy_rounded, size: 18),
          color: AppTheme.moss.withValues(alpha: .6),
          onPressed: () async {
            await Clipboard.setData(ClipboardData(text: text));
            if (!mounted) return;
            ScaffoldMessenger.of(context)
              ..hideCurrentSnackBar()
              ..showSnackBar(SnackBar(content: Text('Đã sao chép $what')));
          },
        ),
      ],
    );
  }

  /// 1 lượt nói. Mặc định THU GỌN (giờ + 1 dòng câu nguồn); chạm để mở chi tiết.
  /// Nút xóa luôn hiện ở góc để xóa riêng từng lượt.
  Widget _buildSegment(int index, HistorySegment segment, DateTime start) {
    final key = segment.at.millisecondsSinceEpoch;
    final open = _expanded.contains(key);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: AppTheme.ivory,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () => setState(() {
              if (!_expanded.remove(key)) _expanded.add(key);
            }),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 8, 2, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppTheme.sand,
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                '#${index + 1}',
                                style: TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w800,
                                  color: AppTheme.moss.withValues(alpha: .65),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '${_hms(segment.at)}  (${_offset(start, segment.at)})',
                              style: TextStyle(
                                fontSize: 11.5,
                                color: AppTheme.moss.withValues(alpha: .5),
                              ),
                            ),
                          ],
                        ),
                        if (!open) ...[
                          const SizedBox(height: 4),
                          Text(
                            segment.sourceText,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                          ),
                        ],
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Xóa lượt nói này',
                    visualDensity: VisualDensity.compact,
                    icon: const Icon(Icons.delete_outline_rounded, size: 20),
                    color: AppTheme.cranberry,
                    onPressed: () => _deleteSegment(segment),
                  ),
                  Icon(
                    open ? Icons.expand_less_rounded : Icons.expand_more_rounded,
                    color: AppTheme.moss.withValues(alpha: .5),
                  ),
                  const SizedBox(width: 8),
                ],
              ),
            ),
          ),
          if (open)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 6, 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.sourceName,
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.moss.withValues(alpha: .45),
                          ),
                        ),
                        const SizedBox(height: 2),
                        _sentenceRow(
                          text: segment.sourceText,
                          what: 'câu nguồn',
                          wordLang: widget.item.sourceLanguage,
                          meaningLang: widget.item.targetLanguage,
                          style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          widget.targetName,
                          style: const TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.coral,
                          ),
                        ),
                        const SizedBox(height: 2),
                        _sentenceRow(
                          text: segment.translatedText,
                          what: 'câu đích',
                          wordLang: widget.item.targetLanguage,
                          meaningLang: widget.item.sourceLanguage,
                          style: const TextStyle(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.moss,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Nghe bản dịch',
                    icon: const Icon(Icons.volume_up_rounded),
                    color: AppTheme.moss,
                    onPressed: () => _speak(segment),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
