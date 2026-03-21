import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

// 1. Bridge for SharedPreferences
final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError();
});

// 2. Our custom ThemeNotifier (This contains the setTheme method!)
class ThemeNotifier extends StateNotifier<ThemeMode> {
  final SharedPreferences prefs;

  ThemeNotifier(this.prefs) : super(_loadInitialTheme(prefs));

  static ThemeMode _loadInitialTheme(SharedPreferences prefs) {
    final savedTheme = prefs.getString('app_theme');
    if (savedTheme == 'light') return ThemeMode.light;
    if (savedTheme == 'dark') return ThemeMode.dark;
    return ThemeMode.system;
  }

  // 👇 Here is the method your Profile Screen is looking for!
  void setTheme(ThemeMode mode) {
    state = mode;

    if (mode == ThemeMode.light) {
      prefs.setString('app_theme', 'light');
    } else if (mode == ThemeMode.dark) {
      prefs.setString('app_theme', 'dark');
    } else {
      prefs.setString('app_theme', 'system');
    }
  }
}

// 3. The actual provider
// ⚠️ CRITICAL: It MUST say StateNotifierProvider, not StateProvider!
final themeModeProvider = StateNotifierProvider<ThemeNotifier, ThemeMode>((
  ref,
) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return ThemeNotifier(prefs);
});
