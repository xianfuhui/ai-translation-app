import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/backend_status.dart';
import '../../core/offline_packs.dart';
import '../../core/sync_queue.dart';
import '../../core/theme.dart';
import '../../providers/auth_provider.dart';
import '../../services/offline_packs_service.dart';
import '../../widgets/connection_banner.dart';
import '../auth/login_screen.dart';
import '../models/offline_models_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _packsService = OfflinePacksService();
  DownloadedPacks? _packs; // null = đang kiểm tra

  @override
  void initState() {
    super.initState();
    _refreshPacks();
    // Tải/xóa gói ở bất kỳ màn nào cũng làm danh sách này tự cập nhật.
    OfflinePacks.changes.addListener(_refreshPacks);
  }

  @override
  void dispose() {
    OfflinePacks.changes.removeListener(_refreshPacks);
    super.dispose();
  }

  Future<void> _refreshPacks() async {
    final packs = await _packsService.getDownloaded();
    if (mounted) setState(() => _packs = packs);
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final user = auth.currentUser;
    final displayName =
        user?.fullName.isNotEmpty == true ? user!.fullName : 'Người học';
    final initial = displayName.substring(0, 1).toUpperCase();

    return Scaffold(
      appBar: AppBar(title: const Text('Cá nhân')),
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
                        auth.isGuest
                            ? 'Chế độ khách · dữ liệu lưu trên máy này'
                            : (user?.email ?? 'Bắt đầu hành trình của bạn'),
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
          const ConnectionBanner(),
          Text('Ngoại tuyến', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 10),
          Card(
            child: _ProfileAction(
              icon: Icons.download_for_offline_outlined,
              title: 'Gói ngoại tuyến',
              subtitle: _packs == null
                  ? 'Đang kiểm tra…'
                  : 'Đã tải: ${_packs!.summary}',
              onTap: () async {
                await Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const OfflineModelsScreen()),
                );
                _refreshPacks();
              },
            ),
          ),
          const SizedBox(height: 24),
          Text('Tài khoản', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 10),
          Card(
            child: Column(
              children: auth.isGuest
                  ? [
                      _ProfileAction(
                        icon: Icons.login_rounded,
                        title: 'Đăng nhập / Đăng ký',
                        subtitle: 'Đồng bộ từ vựng và lịch sử, dùng AI',
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const LoginScreen()),
                        ),
                      ),
                      const Divider(indent: 62, endIndent: 16),
                      _ProfileAction(
                        icon: Icons.logout_rounded,
                        title: 'Thoát chế độ khách',
                        subtitle: 'Dữ liệu khách vẫn được giữ trên máy này',
                        destructive: true,
                        onTap: () => _logout(context),
                      ),
                    ]
                  : [
                      _ProfileAction(
                        icon: Icons.sync_rounded,
                        title: 'Đồng bộ ngay',
                        subtitle: 'Gửi các thay đổi đã lưu khi ngoại tuyến lên máy chủ',
                        onTap: () => _syncNow(context),
                      ),
                      const Divider(indent: 62, endIndent: 16),
                      _ProfileAction(
                        icon: Icons.lock_outline_rounded,
                        title: 'Đổi mật khẩu',
                        subtitle: 'Cập nhật thông tin bảo mật (cần mạng)',
                        onTap: () => _showChangePasswordDialog(context),
                      ),
                      const Divider(indent: 62, endIndent: 16),
                      _ProfileAction(
                        icon: Icons.logout_rounded,
                        title: 'Đăng xuất',
                        subtitle: 'Thoát khỏi tài khoản trên thiết bị này',
                        destructive: true,
                        onTap: () => _logout(context),
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

  Future<void> _logout(BuildContext context) async {
    await context.read<AuthProvider>().logout();
    if (context.mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (route) => false,
      );
    }
  }

  Future<void> _syncNow(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    BackendStatus.reset();
    final queue = SyncQueue();
    final before = await queue.pendingCount();
    final done = await queue.flush();
    final after = await queue.pendingCount();
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          done
              ? (before == 0
                  ? 'Mọi thứ đã được đồng bộ'
                  : 'Đã đồng bộ $before thay đổi')
              : 'Chưa kết nối được máy chủ — còn $after thay đổi chờ đồng bộ',
        ),
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
