import 'package:flutter/material.dart';
import 'config/theme.dart';
import 'core/auth_state.dart';
import 'features/auth/login_page.dart';
import 'features/home/home_page.dart';

final authState = AuthState();

void main() {
  runApp(const FamilyFireApp());
}

class FamilyFireApp extends StatelessWidget {
  const FamilyFireApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: authState,
      builder: (context, _) {
        return MaterialApp(
          title: 'Family Fire',
          theme: buildLightTheme(),
          debugShowCheckedModeBanner: false,
          home: authState.isLoggedIn ? const HomePage() : const LoginPage(),
        );
      },
    );
  }
}
