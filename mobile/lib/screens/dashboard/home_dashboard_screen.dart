import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/app_theme.dart';
import '../../providers/auth_provider.dart';

class HomeDashboardScreen extends StatelessWidget {
  final ValueChanged<int> onNavigate;

  const HomeDashboardScreen({super.key, required this.onNavigate});

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().currentUser;
    final firstName = _firstName(user?.fullName);
    final greeting = _greeting(DateTime.now());

    return Scaffold(
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  _buildHeader(context, greeting, firstName),
                  const SizedBox(height: 24),
                  _buildDailyPracticeCard(context),
                  const SizedBox(height: 14),
                  _buildStatsRow(context),
                  const SizedBox(height: 26),
                  _buildSectionHeader(context, 'Bắt đầu nhanh'),
                  const SizedBox(height: 10),
                  _buildQuickActions(context),
                  const SizedBox(height: 26),
                  _buildWordOfTheDay(context),
                  const SizedBox(height: 14),
                  _buildHistoryShortcut(context),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, String greeting, String firstName) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(greeting,
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(color: const Color(0xFF65756D))),
              const SizedBox(height: 3),
              Text(firstName, style: Theme.of(context).textTheme.displaySmall),
              const SizedBox(height: 8),
              Text(
                'Một chút mỗi ngày, tiến bộ thật xa.',
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(color: const Color(0xFF65756D)),
              ),
            ],
          ),
        ),
        Semantics(
          label: 'Mở hồ sơ cá nhân',
          button: true,
          child: IconButton(
            onPressed: () => onNavigate(4),
            style: IconButton.styleFrom(
              backgroundColor: AppTheme.sageWash,
              foregroundColor: AppTheme.pine,
              padding: const EdgeInsets.all(14),
            ),
            icon: const Icon(Icons.person_outline),
          ),
        ),
      ],
    );
  }

  Widget _buildDailyPracticeCard(BuildContext context) {
    return Card(
      color: AppTheme.pine,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 16, 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.14),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Text(
                    'MỤC TIÊU HÔM NAY',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.7),
                  ),
                ),
                const Spacer(),
                const Icon(Icons.local_fire_department_outlined,
                    color: AppTheme.caramel),
                const SizedBox(width: 4),
                const Text('7 ngày',
                    style: TextStyle(
                        color: Colors.white, fontWeight: FontWeight.w700)),
              ],
            ),
            const SizedBox(height: 20),
            Text(
              'Ôn lại 20 từ vựng',
              style: Theme.of(context)
                  .textTheme
                  .headlineSmall
                  ?.copyWith(color: Colors.white),
            ),
            const SizedBox(height: 5),
            Text(
              'Bạn đã hoàn thành 14 từ. Chỉ còn một đoạn ngắn nữa thôi.',
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: Colors.white.withOpacity(0.78)),
            ),
            const SizedBox(height: 18),
            ClipRRect(
              borderRadius: BorderRadius.circular(99),
              child: const LinearProgressIndicator(
                value: 0.7,
                minHeight: 8,
                backgroundColor: Color(0x3DFFFFFF),
                valueColor: AlwaysStoppedAnimation<Color>(AppTheme.caramel),
              ),
            ),
            const SizedBox(height: 16),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.tonalIcon(
                onPressed: () => onNavigate(2),
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: AppTheme.pine,
                ),
                icon: const Icon(Icons.arrow_forward, size: 18),
                label: const Text('Ôn ngay'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsRow(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _StatCard(
            icon: Icons.local_fire_department_outlined,
            label: 'Chuỗi học',
            value: '7 ngày',
            color: AppTheme.apricotWash,
            iconColor: const Color(0xFF9B5D1D),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _StatCard(
            icon: Icons.translate_outlined,
            label: 'Đã dịch',
            value: '128 câu',
            color: AppTheme.salmonWash,
            iconColor: const Color(0xFFAE4A42),
          ),
        ),
      ],
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    return Row(
      children: [
        Text(title, style: Theme.of(context).textTheme.titleLarge),
        const Spacer(),
        TextButton(
          onPressed: () => onNavigate(2),
          child: const Text('Xem thêm'),
        ),
      ],
    );
  }

  Widget _buildQuickActions(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _QuickActionTile(
            icon: Icons.translate_outlined,
            title: 'Dịch nhanh',
            subtitle: 'Viết hoặc nói',
            color: AppTheme.sageWash,
            onTap: () => onNavigate(1),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _QuickActionTile(
            icon: Icons.chat_bubble_outline,
            title: 'Luyện nói',
            subtitle: 'Trò chuyện với AI',
            color: AppTheme.apricotWash,
            onTap: () => onNavigate(3),
          ),
        ),
      ],
    );
  }

  Widget _buildWordOfTheDay(BuildContext context) {
    return Card(
      color: AppTheme.paper,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: AppTheme.sageWash,
                borderRadius: BorderRadius.circular(16),
              ),
              child:
                  const Icon(Icons.auto_stories_outlined, color: AppTheme.pine),
            ),
            const SizedBox(width: 14),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('TỪ CỦA HÔM NAY',
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.7,
                          color: AppTheme.pine)),
                  SizedBox(height: 5),
                  Text('Serendipity',
                      style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.ink)),
                  SizedBox(height: 2),
                  Text('Một điều tốt đẹp đến bất ngờ',
                      style: TextStyle(color: Color(0xFF65756D))),
                ],
              ),
            ),
            IconButton(
              onPressed: () {},
              tooltip: 'Nghe phát âm',
              icon: const Icon(Icons.volume_up_outlined, color: AppTheme.pine),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHistoryShortcut(BuildContext context) {
    return InkWell(
      onTap: () => onNavigate(1),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
        decoration: BoxDecoration(
          border: Border.all(color: AppTheme.warmLine),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          children: [
            const Icon(Icons.history, color: AppTheme.pine),
            const SizedBox(width: 12),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Xem lịch sử dịch',
                      style: TextStyle(
                          fontWeight: FontWeight.w800, color: AppTheme.ink)),
                  SizedBox(height: 3),
                  Text('Những câu bạn đã lưu lại gần đây',
                      style: TextStyle(fontSize: 12, color: Color(0xFF65756D))),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios, size: 15, color: AppTheme.pine),
          ],
        ),
      ),
    );
  }

  String _firstName(String? fullName) {
    final value = fullName?.trim() ?? '';
    if (value.isEmpty) return 'bạn';
    return value.split(RegExp(r'\s+')).last;
  }

  String _greeting(DateTime now) {
    if (now.hour < 12) return 'Chào buổi sáng';
    if (now.hour < 18) return 'Chào buổi chiều';
    return 'Chào buổi tối';
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  final Color iconColor;

  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    required this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration:
          BoxDecoration(color: color, borderRadius: BorderRadius.circular(20)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: iconColor, size: 21),
          const SizedBox(height: 12),
          Text(value, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 2),
          Text(label,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: const Color(0xFF65756D))),
        ],
      ),
    );
  }
}

class _QuickActionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _QuickActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Ink(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
            color: color, borderRadius: BorderRadius.circular(20)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: AppTheme.pine, size: 23),
            const SizedBox(height: 17),
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 3),
            Text(subtitle,
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: const Color(0xFF65756D))),
          ],
        ),
      ),
    );
  }
}
