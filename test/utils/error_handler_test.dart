import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:vote/l10n/app_localizations.dart';
import 'package:vote/utils/error_handler.dart';

/// Minimal mock of [AppLocalizations] that returns the expected English
/// strings for the getters used by [localizedError]. The abstract class has
/// many members, so `noSuchMethod` returns a placeholder for everything
/// else.
class _TestAppLocalizations extends AppLocalizations {
  _TestAppLocalizations() : super('en');

  @override
  String get noInternetConnection => 'No internet connection';

  @override
  String get connectionTimeout => 'Connection timed out';

  @override
  String get connectionFailedGeneric => 'Connection failed';

  @override
  String get serverError => 'Server returned an error';

  @override
  String get unknownError => 'Something went wrong. Please try again.';

  @override
  dynamic noSuchMethod(Invocation invocation) => 'mock';
}

void main() {
  group('classifyError', () {
    test('classifies SocketException as noConnection', () {
      expect(classifyError(const SocketException('')), ErrorType.noConnection);
    });

    test('classifies TimeoutException as timeout', () {
      expect(classifyError(TimeoutException('')), ErrorType.timeout);
    });

    test('classifies HandshakeException as sslError', () {
      expect(classifyError(HandshakeException()), ErrorType.sslError);
    });

    test('classifies FormatException as malformedResponse', () {
      expect(
        classifyError(const FormatException()),
        ErrorType.malformedResponse,
      );
    });

    test('classifies generic Exception as unknown', () {
      expect(classifyError(Exception('some error')), ErrorType.unknown);
    });

    test('classifies Error as unknown', () {
      expect(classifyError(Error()), ErrorType.unknown);
    });

    test('classifies arbitrary object as unknown', () {
      expect(classifyError('a string'), ErrorType.unknown);
    });
  });

  group('localizedError', () {
    final l10n = _TestAppLocalizations();

    test('returns noInternetConnection for SocketException', () {
      expect(
        localizedError(l10n, const SocketException('')),
        'No internet connection',
      );
    });

    test('returns connectionTimeout for TimeoutException', () {
      expect(
        localizedError(l10n, TimeoutException('')),
        'Connection timed out',
      );
    });

    test('returns connectionFailedGeneric for HandshakeException', () {
      expect(localizedError(l10n, HandshakeException()), 'Connection failed');
    });

    test('returns serverError for FormatException', () {
      expect(
        localizedError(l10n, const FormatException()),
        'Server returned an error',
      );
    });

    test('returns unknownError for generic Exception', () {
      expect(
        localizedError(l10n, Exception('Network error')),
        'Something went wrong. Please try again.',
      );
    });

    test('never exposes raw exception text for network errors', () {
      final socketException = const SocketException(
        'Failed to connect to 10.0.2.2:8080. '
        'No address associated with hostname.',
      );
      final message = localizedError(l10n, socketException);
      expect(message, isNot(contains('SocketException')));
      expect(message, isNot(contains('10.0.2.2')));
    });

    test('never exposes raw exception text for timeout errors', () {
      final timeout = TimeoutException(
        'The request exceeded 30s.',
        const Duration(seconds: 30),
      );
      final message = localizedError(l10n, timeout);
      expect(message, isNot(contains('TimeoutException')));
      expect(message, isNot(contains('30s')));
    });
  });

  group('isConnectivityError', () {
    test('returns true for SocketException', () {
      expect(isConnectivityError(const SocketException('')), isTrue);
    });

    test('returns false for TimeoutException', () {
      expect(isConnectivityError(TimeoutException('')), isFalse);
    });

    test('returns false for generic Exception', () {
      expect(isConnectivityError(Exception('test')), isFalse);
    });
  });
}
