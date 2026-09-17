import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:vote/services/navigation_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('NavigationService', () {
    group('navigatorKey', () {
      test('is a GlobalKey<NavigatorState>', () {
        expect(
          NavigationService.navigatorKey,
          isA<GlobalKey<NavigatorState>>(),
        );
      });

      test('is static and shared', () {
        final key1 = NavigationService.navigatorKey;
        final key2 = NavigationService.navigatorKey;
        expect(identical(key1, key2), isTrue);
      });
    });

    group('pushReplacementNamed', () {
      test('returns null when no navigator is attached', () {
        final result = NavigationService.pushReplacementNamed('/login');
        expect(result, isNull);
      });
    });

    group('navigateToLogin', () {
      test('returns null when no navigator is attached', () {
        final result = NavigationService.navigateToLogin();
        expect(result, isNull);
      });
    });
  });
}
