import 'package:flutter/material.dart';
import '../core/theme.dart';
import 'translate/translate_screen.dart';
import 'ai/ai_chat_screen.dart';
import 'vocabulary/vocabulary_screen.dart';
import 'history/history_screen.dart';
import 'profile/profile_screen.dart';

class HomeScreen extends StatefulWidget {
  final int initialIndex;

  const HomeScreen({super.key, this.initialIndex = 0});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late int _index;

  @override
  void initState() {
    super.initState();
    _index = widget.initialIndex.clamp(0, 4);
  }

  final _screens = const [
    TranslateScreen(),
    AIChatScreen(),
    VocabularyScreen(),
    HistoryScreen(),
    ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _index, children: _screens),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (index) => setState(() => _index = index),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.translate_rounded),
            label: 'Dịch',
          ),
          NavigationDestination(
            icon: Icon(Icons.auto_awesome_outlined),
            label: 'AI',
          ),
          NavigationDestination(
            icon: Icon(Icons.bookmark_outline_rounded),
            label: 'Từ vựng',
          ),
          NavigationDestination(
            icon: Icon(Icons.history_rounded),
            label: 'Lịch sử',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline_rounded),
            label: 'Cá nhân',
          ),
        ],
      ),
    );
  }
}

class ScreenIntro extends StatelessWidget {
  final String eyebrow;
  final String title;
  final String? description;

  const ScreenIntro({
    super.key,
    required this.eyebrow,
    required this.title,
    this.description,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppTheme.spaceMd,
        10,
        AppTheme.spaceMd,
        18,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            eyebrow.toUpperCase(),
            style: const TextStyle(
              color: AppTheme.coral,
              fontSize: 11,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.4,
            ),
          ),
          const SizedBox(height: 5),
          Text(title, style: Theme.of(context).textTheme.headlineSmall),
          if (description != null) ...[
            const SizedBox(height: 5),
            Text(
              description!,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppTheme.moss.withValues(alpha: .65),
                  ),
            ),
          ],
        ],
      ),
    );
  }
}
