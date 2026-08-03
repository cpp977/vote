import 'package:flutter/widgets.dart';

/// Simple navigation service exposing a global [NavigatorState] key so
/// non-UI code (e.g. services) can trigger navigation in a controlled way.
class NavigationService {
  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();

  NavigationService._();

  static Future<void>? pushReplacementNamed(String routeName) {
    return navigatorKey.currentState?.pushReplacementNamed(routeName);
  }

  /// Clears the entire navigation stack and pushes the login page.
  ///
  /// Use this when an unauthenticated user hits a restricted endpoint so
  /// they are redirected to login and cannot navigate back to the
  /// restricted page.
  static Future<void>? navigateToLogin() {
    return navigatorKey.currentState?.pushNamedAndRemoveUntil(
      '/login',
      (route) => false,
    );
  }
}
