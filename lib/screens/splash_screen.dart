import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:go_router/go_router.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _checkAuthAndRoute();
  }

  Future<void> _checkAuthAndRoute() async {
    // Add a small delay so your logo shows for a second
    await Future.delayed(const Duration(seconds: 2));

    final session = Supabase.instance.client.auth.currentSession;

    if (session == null) {
      // Not logged in -> Go to Login
      if (mounted) context.go('/login');
    } else {
      // Logged in -> Go EXACTLY where the Login Screen goes!
      if (mounted) context.go('/home');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark
          ? const Color(0xFF121212)
          : const Color(0xFF2C3931),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.eco, size: 80, color: Color(0xFF92D050)),
            const SizedBox(height: 16),
            RichText(
              text: TextSpan(
                style: const TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -1.2,
                  fontFamily: 'Roboto',
                ),
                children: [
                  TextSpan(
                    text: 'Garden',
                    style: TextStyle(
                      color: isDark ? Colors.white : Colors.white,
                    ),
                  ),
                  const TextSpan(
                    text: 'Rich',
                    style: TextStyle(color: Color(0xFF92D050)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            const CircularProgressIndicator(color: Color(0xFF92D050)),
          ],
        ),
      ),
    );
  }
}
