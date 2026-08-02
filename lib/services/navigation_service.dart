import 'package:flutter/widgets.dart';

/// Simple navigation service exposing a global [NavigatorState] key so
/// non-UI code (e.g. services) can trigger navigation in a controlled way.
class NavigationService {
  static final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  NavigationService._();

  static Future<void>? pushReplacementNamed(String routeName) {
    return navigatorKey.currentState?.pushReplacementNamed(routeName);
  }
}
