import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// GLOBAL STATE (The "Brain" for the Theme)
final themeModeProvider = StateProvider<ThemeMode>((ref) => ThemeMode.system);
