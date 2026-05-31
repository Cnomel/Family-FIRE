import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final localeProvider = StateNotifierProvider<LocaleNotifier, Locale?>((ref) {
  return LocaleNotifier();
});

class LocaleNotifier extends StateNotifier<Locale?> {
  LocaleNotifier() : super(const Locale('zh')); // 默认中文

  void setLocale(Locale locale) {
    state = locale;
  }

  void setChinese() => state = const Locale('zh');
  void setEnglish() => state = const Locale('en');
  void setSystem() => state = null;
}
