import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/backend_status.dart';
import '../core/theme.dart';
import '../providers/auth_provider.dart';
import '../screens/auth/login_screen.dart';

/// Slim status strip shown above the main screens:
///  - guest: "data stays on this device" + shortcut to sign in;
///  - signed in but backend unreachable: "offline, changes sync later".
/// Renders nothing when everything is normal.
class ConnectionBanner extends StatelessWidget {
  const ConnectionBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    if (auth.isGuest) {
      return _strip(
        icon: Icons.person_outline_rounded,
        text: 'Chế độ khách · dữ liệu chỉ lưu trên máy này',
        action: 'Đăng nhập',
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const LoginScreen()),
        ),
      );
    }
    return ValueListenableBuilder<bool>(
      valueListenable: BackendStatus.online,
      builder: (context, online, _) {
        if (online) return const SizedBox.shrink();
        return _strip(
          icon: Icons.cloud_off_rounded,
          text: 'Đang ngoại tuyến · thay đổi sẽ tự đồng bộ khi có mạng',
        );
      },
    );
  }

  Widget _strip({
    required IconData icon,
    required String text,
    String? action,
    VoidCallback? onTap,
  }) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppTheme.sand,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.line),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: AppTheme.moss.withValues(alpha: .7)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppTheme.moss.withValues(alpha: .75),
              ),
            ),
          ),
          if (action != null)
            InkWell(
              onTap: onTap,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                child: Text(
                  action,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    color: AppTheme.coral,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
