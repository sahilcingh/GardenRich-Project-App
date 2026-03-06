import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:garden_rich/screens/admin_dashboard_screen.dart';
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
import 'screens/admin_products_screen.dart';
import 'screens/admin_home_screen.dart';
// 👇 NEW: Import the Admin Categories Screen
import 'screens/admin_categories_screen.dart';
import 'screens/admin_store_settings_screen.dart';
import 'screens/admin_orders_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'https://cqdtrsmoqeszhdmippzx.supabase.co',
    anonKey:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImNxZHRyc21vcWVzemhkbWlwcHp4Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzAzOTYxNTksImV4cCI6MjA4NTk3MjE1OX0.xt9ODBbZBNz4cgAQ1eIbNartxS5DV1eaD_JufI4BIt4',
  );

  runApp(const ProviderScope(child: MyApp()));
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
    // 👇 NEW: Register the Admin Categories route
    GoRoute(
      path: '/admin-categories',
      builder: (context, state) => const AdminCategoriesScreen(),
    ),
    GoRoute(
      path: '/admin-orders',
      builder: (context, state) => const AdminOrdersScreen(),
    ),

    GoRoute(
      path: '/admin-products',
      builder: (context, state) => const AdminProductsScreen(),
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
    // Watch the global theme provider (imported from providers/theme_provider.dart)
    final themeMode = ref.watch(themeModeProvider);

    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      title: 'GardenRich',

      // Pass the selected mode (Light, Dark, or System)
      themeMode: themeMode,

      // LIGHT THEME
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.green,
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
          seedColor: Colors.green,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
        fontFamily: 'sans-serif',
        scaffoldBackgroundColor: const Color(0xFF121212),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF121212),
          foregroundColor: Colors.white,
          elevation: 0,
        ),
      ),

      routerConfig: _router,
    );
  }
}
