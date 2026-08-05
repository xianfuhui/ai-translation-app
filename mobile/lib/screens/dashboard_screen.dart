import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/theme.dart';
import '../providers/auth_provider.dart';
import '../widgets/brand_mark.dart';
import 'home_screen.dart';

/// Trang đích sau khi đăng nhập, giúp người học chọn nhanh điểm bắt đầu.
class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  void _openWorkspace(BuildContext context, int index) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => HomeScreen(initialIndex: index),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().currentUser;
    final displayName =
        user?.fullName.isNotEmpty == true ? user!.fullName : 'Người học';
    final greetingName = displayName.split(' ').first;
    final initial = displayName.substring(0, 1).toUpperCase();

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppTheme.spaceMd,
            AppTheme.spaceMd,
            AppTheme.spaceMd,
            AppTheme.spaceXl,
          ),
          children: [
            Row(
              children: [
                const BrandMark(compact: true),
                const Spacer(),
                Semantics(
                  button: true,
                  label: 'Mở trang cá nhân',
                  child: InkWell(
                    borderRadius: BorderRadius.circular(18),
                    onTap: () => _openWorkspace(context, 4),
                    child: Container(
                      width: 42,
                      height: 42,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: AppTheme.coralTint,
                        borderRadius: BorderRadius.circular(15),
                        border: Border.all(color: AppTheme.coral),
                      ),
                      child: Text(
                        initial,
                        style: const TextStyle(
                          color: AppTheme.coral,
                          fontSize: 17,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),
            Text(
              'GÓC HỌC HÔM NAY',
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: AppTheme.coral,
                    fontSize: 11,
                    letterSpacing: 1.4,
                  ),
            ),
            const SizedBox(height: 7),
            Text(
              'Chào, $greetingName.',
              style: Theme.of(context).textTheme.displaySmall,
            ),
            const SizedBox(height: 7),
            Text(
              'Mình bắt đầu bằng một câu nhỏ nhé?',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: AppTheme.moss.withValues(alpha: .66),
                  ),
            ),
            const SizedBox(height: 22),
            _buildPrimaryCard(context),
            const SizedBox(height: 28),
            Text(
              'ĐI NHANH',
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: AppTheme.moss.withValues(alpha: .55),
                    fontSize: 11,
                    letterSpacing: 1.3,
                  ),
            ),
            const SizedBox(height: 10),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _DashboardShortcut(
                    icon: Icons.auto_awesome_rounded,
                    title: 'Luyện cùng AI',
                    description: 'Thử một đoạn hội thoại',
                    color: AppTheme.coralTint,
                    onTap: () => _openWorkspace(context, 1),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _DashboardShortcut(
                    icon: Icons.bookmark_rounded,
                    title: 'Sổ tay từ',
                    description: 'Ôn lại từ đáng nhớ',
                    color: AppTheme.sand,
                    onTap: () => _openWorkspace(context, 2),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            _buildJournalPrompt(context),
            const SizedBox(height: 22),
            OutlinedButton.icon(
              onPressed: () => _openWorkspace(context, 0),
              icon: const Icon(Icons.grid_view_rounded, size: 18),
              label: const Text('Mở toàn bộ không gian học'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPrimaryCard(BuildContext context) {
    return Container(
      clipBehavior: Clip.antiAlias,
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
      decoration: BoxDecoration(
        color: AppTheme.moss,
        borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
      ),
      child: Stack(
        children: [
          Positioned(
            top: -54,
            right: -35,
            child: Container(
              width: 150,
              height: 150,
              decoration: BoxDecoration(
                color: AppTheme.ivory.withValues(alpha: .07),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.translate_rounded,
                color: AppTheme.coral,
                size: 25,
              ),
              const SizedBox(height: 18),
              const Text(
                'Một câu mới,\nmột cách nhìn mới.',
                style: TextStyle(
                  color: AppTheme.ivory,
                  fontFamily: 'serif',
                  fontSize: 25,
                  height: 1.13,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 9),
              Text(
                'Dịch chữ hoặc nói trực tiếp để bắt đầu khám phá.',
                style: TextStyle(
                  color: AppTheme.ivory.withValues(alpha: .72),
                  fontSize: 13,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 18),
              FilledButton.icon(
                onPressed: () => _openWorkspace(context, 0),
                style: FilledButton.styleFrom(
                  backgroundColor: AppTheme.coral,
                  foregroundColor: AppTheme.ivory,
                ),
                icon: const Icon(Icons.arrow_forward_rounded, size: 18),
                label: const Text('Bắt đầu dịch'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildJournalPrompt(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppTheme.spaceMd),
      decoration: BoxDecoration(
        color: AppTheme.ivory,
        borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
        border: Border.all(color: AppTheme.line),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppTheme.sand,
              borderRadius: BorderRadius.circular(13),
            ),
            child: const Icon(
              Icons.lightbulb_outline_rounded,
              color: AppTheme.moss,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Mẹo nhỏ cho hôm nay',
                  style: TextStyle(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 4),
                Text(
                  'Lưu lại một cụm từ thay vì chỉ một từ đơn. Bạn sẽ nhớ nó trong ngữ cảnh tự nhiên hơn.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppTheme.moss.withValues(alpha: .68),
                        height: 1.35,
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DashboardShortcut extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final Color color;
  final VoidCallback onTap;

  const _DashboardShortcut({
    required this.icon,
    required this.title,
    required this.description,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color,
      borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 15, 12, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: AppTheme.moss, size: 22),
              const SizedBox(height: 22),
              Text(
                title,
                style: const TextStyle(
                  color: AppTheme.moss,
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                description,
                style: TextStyle(
                  color: AppTheme.moss.withValues(alpha: .64),
                  fontSize: 12,
                  height: 1.3,
                ),
              ),
              const SizedBox(height: 13),
              const Align(
                alignment: Alignment.bottomRight,
                child: Icon(
                  Icons.arrow_outward_rounded,
                  color: AppTheme.coral,
                  size: 18,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
