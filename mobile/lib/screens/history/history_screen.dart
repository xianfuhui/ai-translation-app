import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/history.dart';
import '../../services/history_service.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final _service = HistoryService();
  List<TranslationHistoryItem> _items = [];
  bool _loading = true;
  // Đang gọi LLM tóm tắt cho mục nào (để hiện loading trên đúng nút đó)
  final Set<String> _summarizing = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final items = await _service.getMyHistory();
      setState(() => _items = items);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Không tải được lịch sử: $e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _delete(TranslationHistoryItem item) async {
    try {
      await _service.deleteHistory(item.id);
      _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Xóa thất bại: $e')));
    }
  }

  /// Gọi LLM tóm tắt nội dung mục lịch sử. Lưu ý: tính năng LLM có giới hạn
  /// số ký tự đầu vào - nếu phiên quá dài, backend sẽ tự cắt bớt trước khi tóm tắt.
  Future<void> _summarize(TranslationHistoryItem item) async {
    setState(() => _summarizing.add(item.id));
    try {
      final summary = await _service.summarizeHistory(item.id);
      final index = _items.indexWhere((e) => e.id == item.id);
      if (index != -1) {
        setState(() {
          _items[index] = TranslationHistoryItem(
            id: item.id,
            sourceLanguage: item.sourceLanguage,
            targetLanguage: item.targetLanguage,
            sourceText: item.sourceText,
            translatedText: item.translatedText,
            type: item.type,
            segments: item.segments,
            startedAt: item.startedAt,
            endedAt: item.endedAt,
            summary: summary,
            createdAt: item.createdAt,
          );
        });
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Tóm tắt thất bại: $e')));
    } finally {
      if (mounted) setState(() => _summarizing.remove(item.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Lịch sử dịch thuật')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _items.isEmpty
              ? const Center(child: Text('Chưa có lịch sử dịch thuật nào'))
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.separated(
                    padding: const EdgeInsets.all(12),
                    itemCount: _items.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, i) {
                      final item = _items[i];
                      return Dismissible(
                        key: ValueKey(item.id),
                        direction: DismissDirection.endToStart,
                        background: Container(
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.only(right: 20),
                          color: Colors.red.shade100,
                          child: const Icon(Icons.delete_outline, color: Colors.red),
                        ),
                        onDismissed: (_) => _delete(item),
                        child: item.isConversation ? _buildConversationCard(item) : _buildSingleCard(item),
                      );
                    },
                  ),
                ),
    );
  }

  Widget _buildHeaderRow(TranslationHistoryItem item) {
    return Row(
      children: [
        Chip(label: Text('${item.sourceLanguage} → ${item.targetLanguage}'), visualDensity: VisualDensity.compact),
        if (item.isConversation) ...[
          const SizedBox(width: 6),
          Chip(
            label: Text('${item.segments.length} lượt'),
            visualDensity: VisualDensity.compact,
            backgroundColor: Theme.of(context).colorScheme.secondaryContainer,
          ),
        ],
        const Spacer(),
        Text(
          DateFormat('dd/MM/yyyy HH:mm').format(item.createdAt),
          style: const TextStyle(fontSize: 11, color: Colors.grey),
        ),
      ],
    );
  }

  /// Dòng hiển thị giờ Bắt đầu -> Dừng và tổng thời lượng của 1 phiên hội thoại.
  Widget _buildSessionTimeRow(TranslationHistoryItem item) {
    final start = item.startedAt;
    final end = item.endedAt;
    if (start == null || end == null) return const SizedBox.shrink();

    final duration = end.difference(start);
    final durationLabel = duration.inMinutes >= 1
        ? '${duration.inMinutes} phút ${duration.inSeconds % 60} giây'
        : '${duration.inSeconds} giây';

    return Padding(
      padding: const EdgeInsets.only(top: 2, bottom: 4),
      child: Row(
        children: [
          const Icon(Icons.schedule, size: 13, color: Colors.grey),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              'Bắt đầu ${DateFormat('HH:mm:ss').format(start)} → Dừng ${DateFormat('HH:mm:ss').format(end)}'
              ' (kéo dài $durationLabel)',
              style: const TextStyle(fontSize: 11, color: Colors.grey),
            ),
          ),
        ],
      ),
    );
  }

  /// Nút "LLM" dùng để tóm tắt nội dung mục lịch sử, và phần hiển thị kết quả
  /// tóm tắt (nếu đã có).
  Widget _buildSummarySection(TranslationHistoryItem item) {
    final isLoading = _summarizing.contains(item.id);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Align(
          alignment: Alignment.centerRight,
          child: TextButton.icon(
            onPressed: isLoading ? null : () => _summarize(item),
            icon: isLoading
                ? const SizedBox(height: 14, width: 14, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.auto_awesome, size: 16),
            label: Text(item.summary == null ? 'Tóm tắt bằng LLM' : 'Tóm tắt lại'),
          ),
        ),
        if (item.summary != null && item.summary!.isNotEmpty)
          Container(
            width: double.infinity,
            margin: const EdgeInsets.only(top: 4),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.4),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.auto_awesome, size: 16),
                const SizedBox(width: 8),
                Expanded(child: Text(item.summary!, style: const TextStyle(fontSize: 13))),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildSingleCard(TranslationHistoryItem item) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeaderRow(item),
            const SizedBox(height: 8),
            Text(item.sourceText, maxLines: 2, overflow: TextOverflow.ellipsis),
            const Divider(),
            Text(item.translatedText, maxLines: 2, overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w500)),
            const Divider(),
            _buildSummarySection(item),
          ],
        ),
      ),
    );
  }

  /// Mục lịch sử dạng "phiên hội thoại" (được tạo khi bấm Bắt đầu -> Dừng dịch
  /// trực tiếp) — gộp nhiều lượt nói, thu gọn mặc định, có nút LLM để tóm tắt
  /// toàn bộ phiên.
  Widget _buildConversationCard(TranslationHistoryItem item) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        child: ExpansionTile(
          tilePadding: EdgeInsets.zero,
          title: _buildHeaderRow(item),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSessionTimeRow(item),
                Text(
                  item.segments.isNotEmpty ? item.segments.first.sourceText : '',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12.5),
                ),
              ],
            ),
          ),
          childrenPadding: const EdgeInsets.only(bottom: 8),
          children: [
            const Divider(height: 1),
            ...item.segments.map(
              (s) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(DateFormat('HH:mm:ss').format(s.at), style: const TextStyle(fontSize: 10, color: Colors.grey)),
                    Text(s.sourceText),
                    Text(s.translatedText, style: const TextStyle(fontWeight: FontWeight.w500)),
                  ],
                ),
              ),
            ),
            const Divider(),
            _buildSummarySection(item),
          ],
        ),
      ),
    );
  }
}
