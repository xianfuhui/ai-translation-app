import 'package:flutter/material.dart';
import 'translate/translate_screen.dart';
import 'history/history_screen.dart';
import 'ai/ai_chat_screen.dart';
import 'vocabulary/vocabulary_screen.dart';
import 'profile/profile_screen.dart';

/// Shell 5 tab: Dịch · Lịch sử · AI · Sổ tay · Cá nhân.
/// - Mở app là vào thẳng tab Dịch.
/// - Lịch sử có tab riêng (không còn mục "Gần đây" trong tab Dịch).
class HomeScreen extends StatefulWidget {
  final int initialIndex;

  const HomeScreen({super.key, this.initialIndex = 0});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

/// Cho màn con đổi tab (vd: avatar ở màn Dịch → tab Cá nhân).
class HomeTabs extends InheritedWidget {
  final void Function(int index) select;

  const HomeTabs({super.key, required this.select, required super.child});

  static HomeTabs? of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<HomeTabs>();

  @override
  bool updateShouldNotify(HomeTabs oldWidget) => false;
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
    HistoryScreen(),
    AIChatScreen(),
    VocabularyScreen(),
    ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return HomeTabs(
      select: (index) => setState(() => _index = index.clamp(0, 4)),
      child: Scaffold(
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
              icon: Icon(Icons.history_rounded),
              label: 'Lịch sử',
            ),
            NavigationDestination(
              icon: Icon(Icons.auto_awesome_outlined),
              label: 'AI',
            ),
            NavigationDestination(
              icon: Icon(Icons.bookmark_outline_rounded),
              label: 'Sổ tay',
            ),
            NavigationDestination(
              icon: Icon(Icons.person_outline_rounded),
              label: 'Cá nhân',
            ),
          ],
        ),
      ),
    );
  }
}
