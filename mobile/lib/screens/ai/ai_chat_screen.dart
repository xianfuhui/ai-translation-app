import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/api_exception.dart';
import '../../core/backend_status.dart';
import '../../core/theme.dart';
import '../../providers/auth_provider.dart';
import '../auth/login_screen.dart';
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
    BackendStatus.reset(); // an explicit user action may retry the network

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
      // Snackbar tự biến mất sau vài giây — nếu chỉ có snackbar, tin nhắn lỗi
      // "bay hơi" và người dùng tưởng app đơ. Thêm bubble lỗi nằm lại trong
      // luồng chat để thất bại luôn nhìn thấy được.
      final offline = e is NetworkException;
      setState(() {
        _messages.add(
          AIMessage(
            role: 'assistant',
            content: offline
                ? 'Mình cần kết nối mạng để trả lời. Các tính năng dịch, '
                    'từ vựng và flashcard vẫn dùng được ngoại tuyến — '
                    'bạn thử lại khi có mạng nhé.'
                : 'Mình chưa nhận được phản hồi từ AI (lỗi máy chủ hoặc mạng). '
                    'Bạn gửi lại tin nhắn thử nhé.',
          ),
        );
      });
      _scrollToBottom();
      if (!offline) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Lỗi gửi tin nhắn: $e')));
      }
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

  /// Guests have no account, so there is no AI session to talk to.
  Widget _buildGuestLock() {
    return Scaffold(
      appBar: AppBar(title: const Text('Luyện cùng AI')),
      body: Center(
        child: Padding(
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
                child: const Icon(Icons.cloud_off_rounded,
                    color: AppTheme.coral, size: 32),
              ),
              const SizedBox(height: 20),
              Text(
                'AI cần tài khoản\nvà kết nối mạng.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 10),
              Text(
                'Bạn đang ở chế độ khách. Dịch, từ vựng và flashcard vẫn dùng '
                'được hoàn toàn ngoại tuyến; đăng nhập để trò chuyện với AI.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppTheme.moss.withValues(alpha: .64),
                    ),
              ),
              const SizedBox(height: 22),
              FilledButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                ),
                child: const Text('Đăng nhập / Đăng ký'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (context.watch<AuthProvider>().isGuest) return _buildGuestLock();
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
                // UI v2: chạm gợi ý là GỬI LUÔN, không chỉ điền vào ô nhập.
                _PromptChip(
                  label: 'Sửa câu này giúp mình',
                  onPressed: () {
                    _inputController.text =
                        'Fix this sentence: I goes to school yesterday';
                    _sendMessage();
                  },
                ),
                _PromptChip(
                  label: 'Luyện hội thoại ngắn',
                  onPressed: () {
                    _inputController.text =
                        'Luyện hội thoại ngắn với mình nhé';
                    _sendMessage();
                  },
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

/// Bubble theo UI v2: tin của MÌNH căn phải — chữ coral với thanh dọc coral,
/// không avatar; tin của AI là card ngà căn trái.
class _MessageBubble extends StatelessWidget {
  final AIMessage message;
  const _MessageBubble({required this.message});

  @override
  Widget build(BuildContext context) {
    final isUser = message.role == 'user';
    final maxWidth = MediaQuery.of(context).size.width * .74;

    if (isUser) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Align(
          alignment: Alignment.centerRight,
          child: Container(
            constraints: BoxConstraints(maxWidth: maxWidth),
            padding: const EdgeInsets.only(left: 10),
            decoration: const BoxDecoration(
              border: Border(
                left: BorderSide(color: AppTheme.coral, width: 3),
              ),
            ),
            child: Text(
              message.content,
              style: const TextStyle(
                color: AppTheme.coral,
                fontSize: 15,
                height: 1.4,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Container(
          constraints: BoxConstraints(maxWidth: maxWidth),
          padding: const EdgeInsets.fromLTRB(15, 13, 15, 13),
          decoration: BoxDecoration(
            color: AppTheme.ivory,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: AppTheme.moss.withValues(alpha: .05),
                blurRadius: 4,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: Text(
            message.content,
            style: const TextStyle(
              color: AppTheme.moss,
              fontSize: 14.5,
              height: 1.55,
            ),
          ),
        ),
      ),
    );
  }
}
