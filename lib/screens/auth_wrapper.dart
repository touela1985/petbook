import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../data/pet_repository.dart';
import '../services/auth_service.dart';
import 'login_screen.dart';
import 'main_navigation.dart';

class AuthWrapper extends StatelessWidget {
  final PetRepository repo;
  final Future<void> Function(Locale? locale)? onChangeLocale;
  final Locale? currentLocale;

  const AuthWrapper({
    super.key,
    required this.repo,
    this.onChangeLocale,
    this.currentLocale,
  });

  @override
  Widget build(BuildContext context) {
    final authService = AuthService();

    return StreamBuilder<User?>(
      stream: authService.authStateChanges,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasData) {
          return MainNavigation(
            repo: repo,
            onChangeLocale: onChangeLocale,
            currentLocale: currentLocale,
          );
        }

        return const LoginScreen();
      },
    );
  }
}
