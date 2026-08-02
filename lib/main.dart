import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'config/api_config.dart';
import 'controllers/auth_controller.dart';
import 'pages/login_page.dart';
import 'pages/home_shell.dart';
import 'l10n/app_localizations.dart';
import 'services/navigation_service.dart';
import 'pages/account_locked_page.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AuthController()..checkAuthStatus(),
      child: MaterialApp(
        title: 'Vote',
        navigatorKey: NavigationService.navigatorKey,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
          useMaterial3: true,
        ),
        home: const AuthGate(),
        routes: {
          '/login': (context) => const LoginPage(),
          '/account-locked': (context) => const AccountLockedPage(),
        },
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
      ),
    );
  }
}

/// Widget that shows login page or home page based on auth state.
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthController>(
      builder: (context, auth, _) {
        if (auth.isLoading) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (auth.isAuthenticated) {
          return const HomeShell();
        }
        return const LoginPage();
      },
    );
  }
}
