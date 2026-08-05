import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/app_theme.dart';
import '../../providers/auth_provider.dart';
import '../auth/login_screen.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final user = auth.currentUser;
    final initial = (user?.fullName.isNotEmpty ?? false)
        ? user!.fullName[0].toUpperCase()
        : '?';

    return Scaffold(
      appBar: AppBar(title: const Text('Cá nhân')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
        children: [
          Card(
            color: AppTheme.pine,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 30,
                    backgroundColor: AppTheme.caramel,
                    foregroundColor: AppTheme.ink,
                    child: Text(initial,
                        style: const TextStyle(
                            fontSize: 24, fontWeight: FontWeight.w800)),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(user?.fullName ?? 'Người học',
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.w800)),
                        const SizedBox(height: 4),
                        Text(user?.email ?? '',
                            style: TextStyle(
                                color: Colors.white.withOpacity(0.72))),
                      ],
                    ),
                  ),
                  const Icon(Icons.verified_user_outlined,
                      color: AppTheme.caramel),
                ],
              ),
            ),
          ),
          const SizedBox(height: 28),
          _sectionLabel('Tài khoản'),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: [
                _ProfileRow(
                  icon: Icons.lock_outline,
                  title: 'Đổi mật khẩu',
                  subtitle: 'Cập nhật mật khẩu đăng nhập',
                  onTap: () => _showChangePasswordDialog(context),
                ),
                const Divider(indent: 58, endIndent: 16),
                _ProfileRow(
                  icon: Icons.logout,
                  title: 'Đăng xuất',
                  subtitle: 'Kết thúc phiên trên thiết bị này',
                  iconColor: AppTheme.salmon,
                  titleColor: const Color(0xFFAE4A42),
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
          _sectionLabel('Về Lingo'),
          const SizedBox(height: 8),
          Card(
            child: _ProfileRow(
              icon: Icons.info_outline,
              title: 'Phiên bản ứng dụng',
              subtitle: '1.0.0',
              showChevron: false,
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionLabel(String label) {
    return Text(label.toUpperCase(),
        style: const TextStyle(
            fontSize: 11,
            letterSpacing: 1,
            fontWeight: FontWeight.w800,
            color: AppTheme.pine));
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
                decoration: const InputDecoration(labelText: 'Mật khẩu cũ')),
            const SizedBox(height: 12),
            TextField(
                controller: newController,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'Mật khẩu mới')),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Hủy')),
          FilledButton(
            onPressed: () async {
              final success = await dialogContext
                  .read<AuthProvider>()
                  .changePassword(oldController.text, newController.text);
              if (!dialogContext.mounted) return;
              Navigator.pop(dialogContext);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                    content: Text(success
                        ? 'Đổi mật khẩu thành công'
                        : 'Đổi mật khẩu thất bại')),
              );
            },
            child: const Text('Lưu'),
          ),
        ],
      ),
    );
  }
}

class _ProfileRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color? iconColor;
  final Color? titleColor;
  final VoidCallback? onTap;
  final bool showChevron;

  const _ProfileRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.iconColor,
    this.titleColor,
    this.onTap,
    this.showChevron = true,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.fromLTRB(16, 7, 12, 7),
      leading: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
            color: AppTheme.sageWash, borderRadius: BorderRadius.circular(12)),
        child: Icon(icon, size: 20, color: iconColor ?? AppTheme.pine),
      ),
      title: Text(title,
          style: TextStyle(
              fontWeight: FontWeight.w800, color: titleColor ?? AppTheme.ink)),
      subtitle: Text(subtitle,
          style: const TextStyle(fontSize: 12, color: Color(0xFF65756D))),
      trailing: showChevron
          ? const Icon(Icons.chevron_right, color: AppTheme.pine)
          : null,
      onTap: onTap,
    );
  }
}
