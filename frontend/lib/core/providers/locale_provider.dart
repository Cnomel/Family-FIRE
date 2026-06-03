import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

final localeProvider = StateNotifierProvider<LocaleNotifier, Locale?>((ref) {
  return LocaleNotifier();
});

class LocaleNotifier extends StateNotifier<Locale?> {
  static const _prefKey = 'locale_code';

  LocaleNotifier() : super(null) {
    _loadFromPrefs();
  }

  Future<void> _loadFromPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final code = prefs.getString(_prefKey);
      if (code == null) {
        state = null; // 跟随系统
      } else if (code == 'zh') {
        state = const Locale('zh');
      } else if (code == 'en') {
        state = const Locale('en');
      }
    } catch (e) {
      debugPrint('Failed to load locale: $e');
    }
  }

  Future<void> _saveToPrefs(String? code) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (code == null) {
        await prefs.remove(_prefKey);
      } else {
        await prefs.setString(_prefKey, code);
      }
    } catch (e) {
      debugPrint('Failed to save locale: $e');
    }
  }

  void setLocale(Locale locale) {
    state = locale;
    _saveToPrefs(locale.languageCode);
  }

  void setChinese() {
    state = const Locale('zh');
    _saveToPrefs('zh');
  }

  void setEnglish() {
    state = const Locale('en');
    _saveToPrefs('en');
  }

  void setSystem() {
    state = null;
    _saveToPrefs(null);
  }
}
