import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/auth_provider.dart';
import 'screens/splash_screen.dart';

void main() {
  runApp(const LanguageApp());
}

class LanguageApp extends StatelessWidget {
  const LanguageApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
      ],
      child: MaterialApp(
        title: 'Language App',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          colorSchemeSeed: const Color(0xFF1B4B43), // xanh rêu đậm, đồng bộ với Web Admin
        ),
        home: const SplashScreen(),
      ),
    );
  }
}
