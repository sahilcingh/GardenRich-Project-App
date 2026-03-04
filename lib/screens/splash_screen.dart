import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  late Animation<Offset> _gardenSlide;
  late Animation<double> _gardenFade;

  late Animation<Offset> _richSlide;
  late Animation<double> _richFade;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    _gardenSlide = Tween<Offset>(begin: const Offset(0, 0.5), end: Offset.zero)
        .animate(
          CurvedAnimation(
            parent: _controller,
            curve: const Interval(0.0, 0.6, curve: Curves.easeOutCubic),
          ),
        );
    _gardenFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.6, curve: Curves.easeIn),
      ),
    );

    _richSlide = Tween<Offset>(begin: const Offset(0, 0.5), end: Offset.zero)
        .animate(
          CurvedAnimation(
            parent: _controller,
            curve: const Interval(0.3, 0.9, curve: Curves.easeOutCubic),
          ),
        );
    _richFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.3, 0.9, curve: Curves.easeIn),
      ),
    );

    _controller.forward().then((_) async {
      await Future.delayed(const Duration(milliseconds: 1000));

      if (!mounted) return;

      // Grab the absolute latest user state
      final user = Supabase.instance.client.auth.currentUser;

      // 1. If not logged in, go to login screen
      if (user == null || user.email == null) {
        context.go('/login');
        return;
      }

      // 2. If logged in, perfectly check their role using their lowercase EMAIL
      try {
        final response = await Supabase.instance.client
            .from('profiles')
            .select('role')
            .eq(
              'email',
              user.email!.trim().toLowerCase(),
            ) // 👈 Bulletproof check!
            .maybeSingle();

        if (mounted) {
          if (response != null) {
            final role =
                response['role']?.toString().trim().toUpperCase() ?? 'USER';

            if (role == 'ADMIN') {
              context.go('/admin-home');
              return;
            }
          }

          context.go('/home');
        }
      } catch (e) {
        debugPrint("Splash Routing Error: $e");
        if (mounted) context.go('/home');
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? Colors.grey[900] : Colors.white;

    return Scaffold(
      backgroundColor: bgColor,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SlideTransition(
              position: _gardenSlide,
              child: FadeTransition(
                opacity: _gardenFade,
                child: const Text(
                  'Garden',
                  style: TextStyle(
                    fontSize: 56,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF16a34a),
                    height: 1.0,
                    letterSpacing: -1.5,
                    fontFamily: 'Roboto',
                  ),
                ),
              ),
            ),
            SlideTransition(
              position: _richSlide,
              child: FadeTransition(
                opacity: _richFade,
                child: Text(
                  'Rich',
                  style: TextStyle(
                    fontSize: 56,
                    fontWeight: FontWeight.w900,
                    color: isDark ? Colors.white : const Color(0xFF18181b),
                    height: 1.0,
                    letterSpacing: -1.5,
                    fontFamily: 'Roboto',
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
