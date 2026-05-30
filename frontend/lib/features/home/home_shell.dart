import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../shared/widgets/privacy_toggle.dart';

class HomeShell extends ConsumerStatefulWidget {
  final Widget child;
  const HomeShell({super.key, required this.child});

  @override
  ConsumerState<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends ConsumerState<HomeShell> {
  int _currentIndex = 0;

  static const _tabs = [
    {'path': '/', 'label': '首页', 'icon': Icons.home},
    {'path': '/assets', 'label': '资产', 'icon': Icons.account_balance_wallet},
    {'path': '/finance', 'label': '财务', 'icon': Icons.trending_up},
    {'path': '/documents', 'label': '文档', 'icon': Icons.folder},
    {'path': '/mine', 'label': '我的', 'icon': Icons.person},
  ];

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).matchedLocation;
    _currentIndex = _tabs.indexWhere((t) => t['path'] == location);
    if (_currentIndex < 0) _currentIndex = 0;

    return Scaffold(
      appBar: AppBar(
        title: Text(_tabs[_currentIndex]['label'] as String),
        actions: [
          const PrivacyToggle(),
          IconButton(
            icon: const Icon(Icons.notifications_outlined),
            onPressed: () => context.push('/notifications'),
          ),
        ],
      ),
      body: widget.child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) {
          context.go(_tabs[index]['path'] as String);
        },
        destinations: _tabs.map((tab) {
          return NavigationDestination(
            icon: Icon(tab['icon'] as IconData),
            label: tab['label'] as String,
          );
        }).toList(),
      ),
    );
  }
}
