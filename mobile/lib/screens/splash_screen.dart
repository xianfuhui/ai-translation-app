import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/theme.dart';
import '../providers/auth_provider.dart';
import 'auth/login_screen.dart';
import 'dashboard_screen.dart';
import '../widgets/brand_mark.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _init());
  }

  Future<void> _init() async {
    final auth = context.read<AuthProvider>();
    await auth.tryRestoreSession();
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => auth.status == AuthStatus.authenticated
            ? const DashboardScreen()
            : const LoginScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.moss,
      body: Stack(
        children: [
          Positioned(
            top: -90,
            right: -70,
            child: Container(
              width: 230,
              height: 230,
              decoration: const BoxDecoration(
                color: AppTheme.coral,
                shape: BoxShape.circle,
              ),
            ),
          ),
          Positioned(
            bottom: -110,
            left: -85,
            child: Container(
              width: 260,
              height: 260,
              decoration: BoxDecoration(
                color: AppTheme.ivory.withValues(alpha: .08),
                shape: BoxShape.circle,
              ),
            ),
          ),
          SafeArea(
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const BrandMark(onDark: true),
                  const SizedBox(height: 22),
                  Text(
                    'Ngôn ngữ mở ra\nnhững cuộc gặp gỡ.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          color: AppTheme.ivory,
                          height: 1.18,
                        ),
                  ),
                  const SizedBox(height: 34),
                  const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppTheme.coral,
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
}
