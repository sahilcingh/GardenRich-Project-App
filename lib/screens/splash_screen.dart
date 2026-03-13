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
    // Give the splash screen a tiny delay so it doesn't flash too fast
    // Increased slightly to ensure local storage is fully read on cold boot
    await Future.delayed(const Duration(milliseconds: 1500));

    if (!mounted) return;

    final session = Supabase.instance.client.auth.currentSession;

    // 1. If nobody is logged in, send them straight to Login
    if (session == null || session.user.email == null) {
      context.go('/login');
      return;
    }

    final user = session.user;

    try {
      // 2. Fetch role from DB
      final profileResponse = await Supabase.instance.client
          .from('profiles')
          .select('role')
          .eq('email', user.email!.trim().toLowerCase())
          .maybeSingle();

      final dbRole = profileResponse?['role']?.toString().toUpperCase() ?? '';

      // 3. Fetch from local metadata (BULLETPROOF FALLBACK)
      final metaRole =
          user.userMetadata?['role']?.toString().toUpperCase() ?? '';

      if (!mounted) return;

      // 4. If EITHER source confirms they are an admin, send them to the Admin Home
      if (dbRole == 'ADMIN' || metaRole == 'ADMIN') {
        context.go('/admin-home');
      } else {
        context.go('/home');
      }
    } catch (e) {
      debugPrint("Error checking role on splash screen: $e");

      // 5. Ultimate Fallback: If the database is completely blocked on cold boot,
      // rely on the local metadata to make the routing decision.
      final metaRole =
          user.userMetadata?['role']?.toString().toUpperCase() ?? '';
      if (!mounted) return;

      if (metaRole == 'ADMIN') {
        context.go('/admin-home');
      } else {
        context.go('/home');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF121212) : const Color(0xFFF3F4F6);

    return Scaffold(
      backgroundColor: bgColor,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Leaf Icon
            const Icon(Icons.eco, color: Color(0xFF92D050), size: 80),
            const SizedBox(height: 16),

            // GardenRich Text
            RichText(
              text: TextSpan(
                style: const TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -1.2,
                  fontFamily: 'Roboto',
                ),
                children: [
                  TextSpan(
                    text: 'Garden',
                    style: TextStyle(
                      color: isDark ? Colors.white : const Color(0xFF18181b),
                    ),
                  ),
                  const TextSpan(
                    text: 'Rich',
                    style: TextStyle(color: Color(0xFF92D050)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),

            // Loading Indicator
            const CircularProgressIndicator(color: Color(0xFF92D050)),
          ],
        ),
      ),
    );
  }
}
