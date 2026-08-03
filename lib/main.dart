import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'controllers/auth_controller.dart';
import 'controllers/configuration_controller.dart';
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
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => AuthController()..checkAuthStatus(),
        ),
        ChangeNotifierProvider(
          create: (_) => ConfigurationController()..loadSavedColor(),
        ),
      ],
      child: Consumer<ConfigurationController>(
        builder: (context, config, _) {
          return MaterialApp(
            title: 'Vote',
            navigatorKey: NavigationService.navigatorKey,
            theme: ThemeData(
              colorScheme:
                  ColorScheme.fromSeed(seedColor: config.seedColor),
              useMaterial3: true,
            ),
            home: const AuthGate(),
            routes: {
              '/login': (context) => const LoginPage(),
              '/account-locked': (context) => const AccountLockedPage(),
            },
            localizationsDelegates:
                AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
          );
        },
      ),
    );
  }
}

/// Widget that shows login page or home page based on auth state.
///
/// Unauthenticated users see [HomeShell] (the public question listing)
/// by default.  When [AuthController.showLoginPage] is `true` (e.g.
/// after a 401 on a restricted endpoint) the [LoginPage] is shown
/// instead so the user can sign in.
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
        if (auth.showLoginPage) {
          return const LoginPage();
        }
        return const HomeShell();
      },
    );
  }
}
