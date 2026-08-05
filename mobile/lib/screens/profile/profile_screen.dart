import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme.dart';
import '../../providers/auth_provider.dart';
import '../auth/login_screen.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final user = auth.currentUser;
    final displayName =
        user?.fullName.isNotEmpty == true ? user!.fullName : 'Người học';
    final initial = displayName.substring(0, 1).toUpperCase();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Cá nhân'),
        actions: [
          IconButton(
            tooltip: 'Cài đặt tài khoản',
            icon: const Icon(Icons.tune_rounded),
            onPressed: () => _showChangePasswordDialog(context),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppTheme.spaceMd,
          8,
          AppTheme.spaceMd,
          32,
        ),
        children: [
          Container(
            padding: const EdgeInsets.all(AppTheme.spaceLg),
            decoration: BoxDecoration(
              color: AppTheme.moss,
              borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
            ),
            child: Row(
              children: [
                Container(
                  width: 64,
                  height: 64,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppTheme.coral,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    initial,
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                      color: AppTheme.ivory,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        displayName,
                        style: const TextStyle(
                          color: AppTheme.ivory,
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        user?.email ?? 'Bắt đầu hành trình của bạn',
                        style: TextStyle(
                          color: AppTheme.ivory.withValues(alpha: .72),
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Text('Tài khoản', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 10),
          Card(
            child: Column(
              children: [
                _ProfileAction(
                  icon: Icons.lock_outline_rounded,
                  title: 'Đổi mật khẩu',
                  subtitle: 'Cập nhật thông tin bảo mật',
                  onTap: () => _showChangePasswordDialog(context),
                ),
                const Divider(indent: 62, endIndent: 16),
                _ProfileAction(
                  icon: Icons.logout_rounded,
                  title: 'Đăng xuất',
                  subtitle: 'Thoát khỏi tài khoản trên thiết bị này',
                  destructive: true,
                  onTap: () async {
                    await context.read<AuthProvider>().logout();
                    if (context.mounted) {
                      Navigator.of(context).pushAndRemoveUntil(
                        MaterialPageRoute(builder: (_) => const LoginScreen()),
                        (route) => false,
                      );
                    }
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Text('Về Lingua', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 10),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(AppTheme.spaceMd),
              child: Row(
                children: [
                  const Icon(Icons.auto_awesome_rounded, color: AppTheme.coral),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Một góc nhỏ để dịch, luyện tập và giữ lại những từ đáng nhớ.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showChangePasswordDialog(BuildContext context) {
    final oldController = TextEditingController();
    final newController = TextEditingController();

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Đổi mật khẩu'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: oldController,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Mật khẩu cũ'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: newController,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Mật khẩu mới'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () async {
              final success = await dialogContext
                  .read<AuthProvider>()
                  .changePassword(oldController.text, newController.text);
              if (!dialogContext.mounted) return;
              Navigator.pop(dialogContext);
              final message =
                  success ? 'Đổi mật khẩu thành công' : 'Đổi mật khẩu thất bại';
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(SnackBar(content: Text(message)));
            },
            child: const Text('Lưu'),
          ),
        ],
      ),
    ).whenComplete(() {
      oldController.dispose();
      newController.dispose();
    });
  }
}

class _ProfileAction extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool destructive;
  final VoidCallback onTap;

  const _ProfileAction({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.destructive = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = destructive ? AppTheme.cranberry : AppTheme.moss;
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
      leading: Container(
        width: 40,
        height: 40,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color:
              destructive ? AppTheme.cranberry.withValues(alpha: .1) : AppTheme.sand,
          borderRadius: BorderRadius.circular(13),
        ),
        child: Icon(icon, color: color, size: 20),
      ),
      title: Text(
        title,
        style: TextStyle(color: color, fontWeight: FontWeight.w800),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(color: AppTheme.moss.withValues(alpha: .56), fontSize: 12),
      ),
      trailing: Icon(
        Icons.chevron_right_rounded,
        color: AppTheme.moss.withValues(alpha: .35),
      ),
      onTap: onTap,
    );
  }
}
