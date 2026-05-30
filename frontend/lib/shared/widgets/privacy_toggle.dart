import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:family_fire/core/providers/privacy_provider.dart';

/// 隐私切换按钮
class PrivacyToggle extends ConsumerWidget {
  final double size;

  const PrivacyToggle({super.key, this.size = 24});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isPrivacy = ref.watch(privacyModeProvider);

    return IconButton(
      icon: Icon(
        isPrivacy ? Icons.visibility_off : Icons.visibility,
        size: size,
      ),
      onPressed: () {
        ref.read(privacyModeProvider.notifier).toggle();
      },
      tooltip: isPrivacy ? '显示金额' : '隐藏金额',
    );
  }
}
