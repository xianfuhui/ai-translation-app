import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../auth/login_screen.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final user = auth.currentUser;

    return Scaffold(
      appBar: AppBar(title: const Text('Cá nhân')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          CircleAvatar(
            radius: 36,
            child: Text(
              (user?.fullName.isNotEmpty ?? false) ? user!.fullName[0].toUpperCase() : '?',
              style: const TextStyle(fontSize: 28),
            ),
          ),
          const SizedBox(height: 12),
          Center(child: Text(user?.fullName ?? '', style: Theme.of(context).textTheme.titleLarge)),
          Center(child: Text(user?.email ?? '', style: const TextStyle(color: Colors.grey))),
          const SizedBox(height: 24),
          Card(
            child: ListTile(
              leading: const Icon(Icons.lock_outline),
              title: const Text('Đổi mật khẩu'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _showChangePasswordDialog(context),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: ListTile(
              leading: const Icon(Icons.logout, color: Colors.red),
              title: const Text('Đăng xuất', style: TextStyle(color: Colors.red)),
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
            TextField(controller: oldController, obscureText: true, decoration: const InputDecoration(labelText: 'Mật khẩu cũ')),
            TextField(controller: newController, obscureText: true, decoration: const InputDecoration(labelText: 'Mật khẩu mới')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Hủy')),
          FilledButton(
            onPressed: () async {
              final success = await dialogContext
                  .read<AuthProvider>()
                  .changePassword(oldController.text, newController.text);
              if (!dialogContext.mounted) return;
              Navigator.pop(dialogContext);
              final message = success ? 'Đổi mật khẩu thành công' : 'Đổi mật khẩu thất bại';
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
            },
            child: const Text('Lưu'),
          ),
        ],
      ),
    );
  }
}
