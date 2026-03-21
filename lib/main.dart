import 'package:flutter/material.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart'; // 👇 NEW: Import shared_preferences
import 'package:garden_rich/screens/admin_dashboard_screen.dart';
import 'package:garden_rich/screens/admin_order_details_screen.dart';
import 'package:garden_rich/screens/edit_profile_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:go_router/go_router.dart';

import 'providers/theme_provider.dart';
import 'screens/address_book_screen.dart';
import 'screens/splash_screen.dart';
import 'screens/home_screen.dart';
import 'screens/login_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/checkout_screen.dart';
import 'screens/place_order_screen.dart';
import 'screens/order_details_screen.dart';
import 'screens/order_screen.dart';
import 'screens/admin_home_screen.dart';
import 'screens/help_screen.dart';
import 'screens/about_us_screen.dart';
import 'screens/admin_categories_screen.dart';
import 'screens/admin_store_settings_screen.dart';
import 'screens/admin_orders_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 👇 NEW: Load SharedPreferences BEFORE the app boots up!
  final prefs = await SharedPreferences.getInstance();

  await Supabase.initialize(
    url: 'https://cqdtrsmoqeszhdmippzx.supabase.co',
    anonKey:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImNxZHRyc21vcWVzemhkbWlwcHp4Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzAzOTYxNTksImV4cCI6MjA4NTk3MjE1OX0.xt9ODBbZBNz4cgAQ1eIbNartxS5DV1eaD_JufI4BIt4',
  );

  runApp(
    ProviderScope(
      // 👇 NEW: Inject the loaded preferences directly into Riverpod
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      child: const MyApp(),
    ),
  );
}

final _router = GoRouter(
  initialLocation: '/splash',

  routes: [
    GoRoute(path: '/splash', builder: (context, state) => const SplashScreen()),

    GoRoute(
      path: '/admin-home',
      builder: (context, state) => const AdminHomeScreen(),
    ),
    GoRoute(
      path: '/admin-dashboard',
      builder: (context, state) => const AdminDashboardScreen(),
    ),
    GoRoute(
      path: '/admin-categories',
      builder: (context, state) => const AdminCategoriesScreen(),
    ),
    GoRoute(
      path: '/admin-order-details',
      builder: (context, state) {
        final order = state.extra as Map<String, dynamic>;
        return AdminOrderDetailsScreen(order: order);
      },
    ),
    GoRoute(
      path: '/admin-orders',
      builder: (context, state) => const AdminOrdersScreen(),
    ),
    GoRoute(path: '/help', builder: (context, state) => const HelpScreen()),
    GoRoute(path: '/about', builder: (context, state) => const AboutUsScreen()),
    GoRoute(
      path: '/edit-profile',
      builder: (context, state) => const EditProfileScreen(),
    ),
    GoRoute(
      path: '/order-details',
      builder: (context, state) {
        final orderMap = state.extra as Map<String, dynamic>? ?? {};
        return OrderDetailsScreen(order: orderMap);
      },
    ),
    GoRoute(
      path: '/login',
      builder: (context, state) {
        final isLoginMode = state.extra as bool? ?? true;
        return LoginScreen(initialIsLogin: isLoginMode);
      },
    ),
    GoRoute(
      path: '/address-book',
      builder: (context, state) => const AddressBookScreen(),
    ),
    GoRoute(path: '/home', builder: (context, state) => const HomeScreen()),
    GoRoute(path: '/orders', builder: (context, state) => const OrdersScreen()),
    GoRoute(
      path: '/checkout',
      builder: (context, state) => const CheckoutScreen(),
    ),
    GoRoute(
      path: '/profile',
      builder: (context, state) => const ProfileScreen(),
    ),
    GoRoute(
      path: '/admin-settings',
      builder: (context, state) => const AdminStoreSettingsScreen(),
    ),
    GoRoute(
      path: '/place-order',
      builder: (context, state) {
        final data = state.extra as Map<String, dynamic>? ?? {};
        return PlaceOrderScreen(
          items: data['items'] as List<Map<String, dynamic>>? ?? [],
          total: data['total'] as double? ?? 0.0,
        );
      },
    ),
  ],
);

// ---------------- MY APP (Entry Point) ----------------

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watches the themeModeProvider. Because we loaded SharedPreferences in main(),
    // this instantly knows if it should be Light or Dark!
    final themeMode = ref.watch(themeModeProvider);

    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      title: 'GardenRich',

      builder: (context, child) {
        return NetworkAwareOverlay(child: child!);
      },

      themeMode: themeMode,

      // LIGHT THEME
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF16a34a),
          brightness: Brightness.light,
        ),
        useMaterial3: true,
        fontFamily: 'sans-serif',
        scaffoldBackgroundColor: Colors.white,
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
          elevation: 0,
        ),
      ),

      // DARK THEME
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF16a34a),
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
        fontFamily: 'sans-serif',
        scaffoldBackgroundColor: const Color(0xFF121212),
        appBarTheme: const AppBarTheme(
          backgroundColor: const Color(0xFF121212),
          foregroundColor: Colors.white,
          elevation: 0,
        ),
      ),

      routerConfig: _router,
    );
  }
}

// =====================================================================
// 🌐 GLOBAL NETWORK POPUP OVERLAY
// =====================================================================
class NetworkAwareOverlay extends StatefulWidget {
  final Widget child;
  const NetworkAwareOverlay({super.key, required this.child});

  @override
  State<NetworkAwareOverlay> createState() => _NetworkAwareOverlayState();
}

class _NetworkAwareOverlayState extends State<NetworkAwareOverlay> {
  bool _hasInternet = true;

  @override
  void initState() {
    super.initState();
    _checkInitialConnection();

    Connectivity().onConnectivityChanged.listen((dynamic result) {
      bool isOffline = false;
      if (result is List<ConnectivityResult>) {
        isOffline = result.every((r) => r == ConnectivityResult.none);
      } else if (result is ConnectivityResult) {
        isOffline = result == ConnectivityResult.none;
      }

      if (mounted) {
        setState(() => _hasInternet = !isOffline);
      }
    });
  }

  Future<void> _checkInitialConnection() async {
    final result = await Connectivity().checkConnectivity();
    bool isOffline = false;
    if (result is List<ConnectivityResult>) {
      isOffline = result.every((r) => r == ConnectivityResult.none);
    } else if (result is ConnectivityResult) {
      isOffline = result == ConnectivityResult.none;
    }

    if (mounted) {
      setState(() => _hasInternet = !isOffline);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Stack(
        children: [
          widget.child,
          if (!_hasInternet)
            Positioned.fill(
              child: Material(
                color: Colors.black.withOpacity(0.85),
                child: Center(
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 40),
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2C3931),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: const Color(0xFF16a34a),
                        width: 2,
                      ),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.wifi_off_rounded,
                          color: Colors.white,
                          size: 60,
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          "You are Offline",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          "Please connect to the internet or Wi-Fi to continue using GardenRich.",
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.8),
                            fontSize: 14,
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: 24),
                        const CircularProgressIndicator(
                          color: Color(0xFF16a34a),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          "Waiting for connection...",
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.5),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
