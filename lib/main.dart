import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';

import 'controllers/auth_controller.dart';
import 'controllers/configuration_controller.dart';
import 'pages/login_page.dart';
import 'pages/home_shell.dart';
import 'pages/forgot_password_page.dart';
import 'pages/reset_password_page.dart';
import 'l10n/app_localizations.dart';
import 'services/navigation_service.dart';
import 'services/deep_link_service.dart';
import 'pages/account_locked_page.dart';

import 'gen/dart_define.gen.dart';

void main() {
  final bool allowBadCerts = Dartdefine.flavor == Flavor.development && !kReleaseMode;

  if (allowBadCerts) {
    http.runWithClient(
      () {
        WidgetsFlutterBinding.ensureInitialized();
        runApp(const MyApp());
      },
      () => IOClient(
        HttpClient()..badCertificateCallback = (cert, host, port) => true,
      ),
    );
  } else {
    WidgetsFlutterBinding.ensureInitialized();
    runApp(const MyApp());
  }
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
              colorScheme: ColorScheme.fromSeed(seedColor: config.seedColor),
              useMaterial3: true,
            ),
            home: const DeepLinkWrapper(),
            routes: {
              '/login': (context) => const LoginPage(),
              '/forgot-password': (context) => const ForgotPasswordPage(),
              '/account-locked': (context) => const AccountLockedPage(),
            },
            localizationsDelegates: AppLocalizations.localizationsDelegates,
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

/// Wraps [AuthGate] and listens for password-reset deep links.
///
/// On startup this initialises [DeepLinkService], which:
/// - reads the initial URI (cold-start link on mobile, `Uri.base` on web), and
/// - subscribes to [DeepLinkService.uriStream] for links received while the
///   app is already running (mobile only).
///
/// When a URI pointing at `/reset-password?token=…` is detected the
/// [ResetPasswordPage] is pushed onto the navigation stack via
/// [NavigationService.navigatorKey]. The subscription is stored in state so
/// it is automatically disposed when the widget is unmounted.
class DeepLinkWrapper extends StatefulWidget {
  const DeepLinkWrapper({super.key});

  @override
  State<DeepLinkWrapper> createState() => _DeepLinkWrapperState();
}

class _DeepLinkWrapperState extends State<DeepLinkWrapper> {
  StreamSubscription<Uri?>? _subscription;

  @override
  void initState() {
    super.initState();
    _initDeepLinks();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  Future<void> _initDeepLinks() async {
    final subscription = await DeepLinkService.init(_handleResetToken);
    if (mounted) {
      setState(() => _subscription = subscription);
    }
  }

  /// Navigates to the [ResetPasswordPage] with the token extracted from the
  /// deep link. A post-frame callback is used so that [MaterialApp]'s
  /// navigator is available before we push.
  void _handleResetToken(String token) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      NavigationService.navigatorKey.currentState?.push(
        MaterialPageRoute(builder: (_) => ResetPasswordPage(token: token)),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return const AuthGate();
  }
}
