import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

final themeModeProvider = StateNotifierProvider<ThemeModeNotifier, ThemeMode>((ref) {
  return ThemeModeNotifier();
});

class ThemeModeNotifier extends StateNotifier<ThemeMode> {
  static const _prefKey = 'theme_mode';

  ThemeModeNotifier() : super(ThemeMode.system) {
    _loadFromPrefs();
  }

  Future<void> _loadFromPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final value = prefs.getString(_prefKey);
      switch (value) {
        case 'light':
          state = ThemeMode.light;
          break;
        case 'dark':
          state = ThemeMode.dark;
          break;
        default:
          state = ThemeMode.system;
      }
    } catch (e) {
      debugPrint('Failed to load theme: $e');
    }
  }

  Future<void> _saveToPrefs(ThemeMode mode) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      String value;
      switch (mode) {
        case ThemeMode.light:
          value = 'light';
          break;
        case ThemeMode.dark:
          value = 'dark';
          break;
        case ThemeMode.system:
          value = 'system';
          break;
      }
      await prefs.setString(_prefKey, value);
    } catch (e) {
      debugPrint('Failed to save theme: $e');
    }
  }

  void setThemeMode(ThemeMode mode) {
    state = mode;
    _saveToPrefs(mode);
  }

  void toggleDark() {
    final newMode = state == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
    state = newMode;
    _saveToPrefs(newMode);
  }
}
