import 'package:flutter/material.dart';
import '../../core/theme.dart';
import '../../models/ai_conversation.dart';
import '../../services/ai_service.dart';

class AIChatScreen extends StatefulWidget {
  const AIChatScreen({super.key});

  @override
  State<AIChatScreen> createState() => _AIChatScreenState();
}

class _AIChatScreenState extends State<AIChatScreen> {
  final _aiService = AIService();
  final _inputController = TextEditingController();
  final _scrollController = ScrollController();

  final List<AIMessage> _messages = [];
  String? _conversationId;
  bool _isSending = false;
  bool _isSummarizing = false;

  Future<void> _sendMessage() async {
    final text = _inputController.text.trim();
    if (text.isEmpty) return;

    setState(() {
      _messages.add(AIMessage(role: 'user', content: text));
      _isSending = true;
      _inputController.clear();
    });
    _scrollToBottom();

    try {
      final result = await _aiService.chat(
        conversationId: _conversationId,
        message: text,
      );
      if (!mounted) return;
      setState(() {
        _conversationId = result['conversationId'];
        _messages.add(
          AIMessage(role: 'assistant', content: result['reply'] ?? ''),
        );
      });
      _scrollToBottom();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Lỗi gửi tin nhắn: $e')));
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  Future<void> _summarizeConversation() async {
    if (_conversationId == null) return;
    setState(() => _isSummarizing = true);
    try {
      final summary = await _aiService.summarize(_conversationId!);
      if (!mounted) return;
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Tóm tắt hội thoại'),
          content: Text(summary),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Đóng'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Tóm tắt thất bại: $e')));
    } finally {
      if (mounted) setState(() => _isSummarizing = false);
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  void dispose() {
    _inputController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Luyện cùng AI'),
        actions: [
          if (_conversationId != null)
            IconButton(
              tooltip: 'Tóm tắt hội thoại',
              icon: _isSummarizing
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.auto_awesome_rounded),
              onPressed: _isSummarizing ? null : _summarizeConversation,
            ),
          const SizedBox(width: 6),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child:
                  _messages.isEmpty ? _buildEmptyState() : _buildMessageList(),
            ),
            if (_isSending) const LinearProgressIndicator(minHeight: 2),
            _buildComposer(),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppTheme.spaceXl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppTheme.coralTint,
                borderRadius: BorderRadius.circular(24),
              ),
              child: const Icon(
                Icons.auto_awesome_rounded,
                color: AppTheme.coral,
                size: 32,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Một người bạn để\nluyện ngôn ngữ.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 10),
            Text(
              'Hỏi về ngữ pháp, thử một cuộc hội thoại, hoặc nhờ AI sửa câu cho bạn.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppTheme.moss.withValues(alpha: .64),
                  ),
            ),
            const SizedBox(height: 22),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 8,
              runSpacing: 8,
              children: [
                _PromptChip(
                  label: 'Sửa câu này giúp mình',
                  onPressed: () => setState(
                      () => _inputController.text = 'Sửa câu này giúp mình'),
                ),
                _PromptChip(
                  label: 'Luyện hội thoại ngắn',
                  onPressed: () => setState(
                      () => _inputController.text = 'Luyện hội thoại ngắn'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageList() {
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.fromLTRB(
        AppTheme.spaceMd,
        8,
        AppTheme.spaceMd,
        AppTheme.spaceMd,
      ),
      itemCount: _messages.length,
      itemBuilder: (context, index) =>
          _MessageBubble(message: _messages[index]),
    );
  }

  Widget _buildComposer() {
    return Container(
      padding: const EdgeInsets.fromLTRB(
        AppTheme.spaceMd,
        10,
        AppTheme.spaceMd,
        AppTheme.spaceMd,
      ),
      decoration: const BoxDecoration(
        color: AppTheme.ivory,
        border: Border(top: BorderSide(color: AppTheme.line)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: TextField(
              controller: _inputController,
              minLines: 1,
              maxLines: 4,
              textInputAction: TextInputAction.newline,
              decoration: const InputDecoration(
                hintText: 'Viết tin nhắn cho AI…',
                prefixIcon: Icon(Icons.chat_bubble_outline_rounded),
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
              ),
              onSubmitted: (_) => _sendMessage(),
            ),
          ),
          const SizedBox(width: 8),
          IconButton.filled(
            tooltip: 'Gửi tin nhắn',
            style: IconButton.styleFrom(
              backgroundColor: AppTheme.coral,
              foregroundColor: AppTheme.ivory,
              minimumSize: const Size(52, 52),
            ),
            onPressed: _isSending ? null : _sendMessage,
            icon: const Icon(Icons.arrow_upward_rounded),
          ),
        ],
      ),
    );
  }
}

class _PromptChip extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;
  const _PromptChip({required this.label, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      label: Text(label),
      avatar: const Icon(
        Icons.arrow_outward_rounded,
        size: 15,
        color: AppTheme.coral,
      ),
      onPressed: onPressed,
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final AIMessage message;
  const _MessageBubble({required this.message});

  @override
  Widget build(BuildContext context) {
    final isUser = message.role == 'user';
    final textColor = isUser ? AppTheme.coral : AppTheme.moss;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 9),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 30,
            height: 30,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: isUser ? AppTheme.coralTint : AppTheme.moss,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              isUser
                  ? Icons.person_outline_rounded
                  : Icons.auto_awesome_rounded,
              color: isUser ? AppTheme.coral : AppTheme.ivory,
              size: 17,
            ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Container(
              padding: const EdgeInsets.only(left: 12, top: 2, bottom: 2),
              decoration: BoxDecoration(
                border: Border(
                  left: BorderSide(
                    color: isUser ? AppTheme.coral : AppTheme.line,
                    width: 2,
                  ),
                ),
              ),
              child: Text(
                message.content,
                style: TextStyle(
                  color: textColor,
                  fontSize: 15,
                  height: 1.45,
                  fontWeight: isUser ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
