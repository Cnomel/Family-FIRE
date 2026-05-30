import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 全局隐私模式
final privacyModeProvider = StateNotifierProvider<PrivacyModeNotifier, bool>((ref) {
  return PrivacyModeNotifier();
});

class PrivacyModeNotifier extends StateNotifier<bool> {
  PrivacyModeNotifier() : super(false); // 默认关闭隐私模式

  void toggle() => state = !state;
  void enable() => state = true;
  void disable() => state = false;
}
