import 'package:flutter/material.dart';
import 'translate/translate_screen.dart';
import 'ai/ai_chat_screen.dart';
import 'vocabulary/vocabulary_screen.dart';
import 'history/history_screen.dart';
import 'profile/profile_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _index = 0;

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
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.translate), label: 'Dịch'),
          NavigationDestination(icon: Icon(Icons.smart_toy_outlined), label: 'AI'),
          NavigationDestination(icon: Icon(Icons.menu_book_outlined), label: 'Từ vựng'),
          NavigationDestination(icon: Icon(Icons.history), label: 'Lịch sử'),
          NavigationDestination(icon: Icon(Icons.person_outline), label: 'Cá nhân'),
        ],
      ),
    );
  }
}
