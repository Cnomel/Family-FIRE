import 'package:flutter/material.dart';
import 'utils/theme.dart';
import 'providers/auth_provider.dart';
import 'pages/auth/login_page.dart';
import 'pages/home/home_page.dart';

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
          theme: buildAppTheme(),
          debugShowCheckedModeBanner: false,
          home: authState.isLoggedIn ? const HomePage() : const LoginPage(),
        );
      },
    );
  }
}
