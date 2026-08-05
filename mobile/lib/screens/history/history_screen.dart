import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/theme.dart';
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
      if (!mounted) return;
      setState(() => _items = items);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Không tải được lịch sử: $e')));
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Xóa thất bại: $e')));
    }
  }

  Future<void> _summarize(TranslationHistoryItem item) async {
    setState(() => _summarizing.add(item.id));
    try {
      final summary = await _service.summarizeHistory(item.id);
      final index = _items.indexWhere((entry) => entry.id == item.id);
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Tóm tắt thất bại: $e')));
    } finally {
      if (mounted) setState(() => _summarizing.remove(item.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dấu vết đã dịch'),
        actions: [
          IconButton(
            tooltip: 'Tải lại',
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _load,
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _items.isEmpty
              ? _buildEmptyState()
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(
                      AppTheme.spaceMd,
                      8,
                      AppTheme.spaceMd,
                      AppTheme.spaceLg,
                    ),
                    itemCount: _items.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final item = _items[index];
                      return Dismissible(
                        key: ValueKey(item.id),
                        direction: DismissDirection.endToStart,
                        background: Container(
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.only(right: 22),
                          decoration: BoxDecoration(
                            color: AppTheme.coralTint,
                            borderRadius: BorderRadius.circular(
                              AppTheme.radiusLarge,
                            ),
                          ),
                          child: const Icon(
                            Icons.delete_outline_rounded,
                            color: AppTheme.cranberry,
                          ),
                        ),
                        onDismissed: (_) => _delete(item),
                        child: item.isConversation
                            ? _buildConversationCard(item)
                            : _buildSingleCard(item),
                      );
                    },
                  ),
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
            const Icon(Icons.history_rounded, size: 46, color: AppTheme.sage),
            const SizedBox(height: 18),
            Text(
              'Chưa có lịch sử dịch',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 7),
            Text(
              'Những câu bạn dịch sẽ được lưu lại ở đây.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppTheme.moss.withValues(alpha: .6)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderRow(TranslationHistoryItem item) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
          decoration: BoxDecoration(
            color: AppTheme.coralTint,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            '${item.sourceLanguage} → ${item.targetLanguage}',
            style: const TextStyle(
              color: AppTheme.coral,
              fontSize: 11,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        if (item.isConversation) ...[
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
            decoration: BoxDecoration(
              color: AppTheme.sand,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '${item.segments.length} lượt',
              style: const TextStyle(
                color: AppTheme.moss,
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
        const Spacer(),
        Text(
          DateFormat('dd/MM · HH:mm').format(item.createdAt),
          style: TextStyle(
            fontSize: 11,
            color: AppTheme.moss.withValues(alpha: .5),
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }

  Widget _buildSessionTimeRow(TranslationHistoryItem item) {
    final start = item.startedAt;
    final end = item.endedAt;
    if (start == null || end == null) return const SizedBox.shrink();

    final duration = end.difference(start);
    final durationLabel = duration.inMinutes >= 1
        ? '${duration.inMinutes} phút ${duration.inSeconds % 60} giây'
        : '${duration.inSeconds} giây';
    return Padding(
      padding: const EdgeInsets.only(top: 2, bottom: 6),
      child: Row(
        children: [
          const Icon(Icons.schedule_rounded, size: 13, color: AppTheme.sage),
          const SizedBox(width: 5),
          Expanded(
            child: Text(
              'Bắt đầu ${DateFormat('HH:mm:ss').format(start)} · $durationLabel',
              style: TextStyle(
                fontSize: 11,
                color: AppTheme.moss.withValues(alpha: .55),
              ),
            ),
          ),
        ],
      ),
    );
  }

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
                ? const SizedBox(
                    height: 14,
                    width: 14,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.auto_awesome_rounded, size: 16),
            label: Text(
              item.summary == null ? 'Tóm tắt bằng AI' : 'Tóm tắt lại',
            ),
          ),
        ),
        if (item.summary != null && item.summary!.isNotEmpty)
          Container(
            width: double.infinity,
            margin: const EdgeInsets.only(top: 4),
            padding: const EdgeInsets.all(11),
            decoration: BoxDecoration(
              color: AppTheme.coralTint,
              borderRadius: BorderRadius.circular(13),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.auto_awesome_rounded,
                  size: 16,
                  color: AppTheme.coral,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    item.summary!,
                    style: const TextStyle(fontSize: 13, height: 1.35),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildSingleCard(TranslationHistoryItem item) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 10, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeaderRow(item),
            const SizedBox(height: 14),
            Text(
              item.sourceText,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontFamily: 'serif',
                fontSize: 17,
                height: 1.3,
              ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 10),
              child: Divider(),
            ),
            Text(
              item.translatedText,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                height: 1.4,
              ),
            ),
            _buildSummarySection(item),
          ],
        ),
      ),
    );
  }

  Widget _buildConversationCard(TranslationHistoryItem item) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        child: ExpansionTile(
          tilePadding: EdgeInsets.zero,
          childrenPadding: const EdgeInsets.only(bottom: 10),
          title: _buildHeaderRow(item),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSessionTimeRow(item),
                Text(
                  item.segments.isNotEmpty
                      ? item.segments.first.sourceText
                      : '',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontFamily: 'serif', fontSize: 14),
                ),
              ],
            ),
          ),
          children: [
            const Divider(),
            ...item.segments.map(
              (segment) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 7),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      DateFormat('HH:mm:ss').format(segment.at),
                      style: TextStyle(
                        fontSize: 10,
                        color: AppTheme.moss.withValues(alpha: .5),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      segment.sourceText,
                      style: const TextStyle(fontFamily: 'serif', fontSize: 15),
                    ),
                    Text(
                      segment.translatedText,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
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
