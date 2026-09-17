import 'package:flutter_test/flutter_test.dart';
import 'package:vote/l10n/app_localizations.dart';
import 'package:vote/l10n/auth_error_localization.dart';
import 'package:vote/models/auth_models.dart';

/// Minimal mock of AppLocalizations that returns simple strings for the
/// methods used by localizedAuthError. Uses noSuchMethod to handle any
/// other methods without implementing them all.
class _TestAppLocalizations extends AppLocalizations {
  _TestAppLocalizations() : super('en');

  @override
  String loginFailed(String detail) => 'Login failed: $detail';

  @override
  String registrationFailed(String detail) => 'Registration failed: $detail';

  @override
  String requestFailedStatus(String detail) => 'Request failed: $detail';

  @override
  String profileUpdateFailed(String detail) => 'Profile update failed: $detail';

  @override
  String deleteAccountFailed(String detail) => 'Delete account failed: $detail';

  @override
  String forgotPasswordFailed(String detail) =>
      'Forgot password failed: $detail';

  @override
  String get resetPasswordTokenInvalid => 'Invalid or expired reset token';

  @override
  String passwordResetFailed(String detail) => 'Password reset failed: $detail';

  // noSuchMethod handles all other required methods
  @override
  dynamic noSuchMethod(Invocation invocation) => 'mock';
}

void main() {
  group('localizedAuthError', () {
    final l10n = _TestAppLocalizations();

    test('returns empty string for null error', () {
      expect(localizedAuthError(l10n, null), '');
    });

    group('loginFailed', () {
      test('returns localized message with detail', () {
        const error = AuthError('loginFailed', 'Invalid credentials');
        expect(
          localizedAuthError(l10n, error),
          'Login failed: Invalid credentials',
        );
      });

      test('returns localized message with empty detail', () {
        const error = AuthError('loginFailed', null);
        expect(localizedAuthError(l10n, error), 'Login failed: ');
      });
    });

    group('registrationFailed', () {
      test('returns localized message with detail', () {
        const error = AuthError('registrationFailed', 'Username taken');
        expect(
          localizedAuthError(l10n, error),
          'Registration failed: Username taken',
        );
      });

      test('returns localized message with empty detail', () {
        const error = AuthError('registrationFailed', null);
        expect(localizedAuthError(l10n, error), 'Registration failed: ');
      });
    });

    group('requestFailed', () {
      test('returns localized message with status code', () {
        const error = AuthError('requestFailed', '500');
        expect(localizedAuthError(l10n, error), 'Request failed: 500');
      });

      test('returns localized message with empty detail', () {
        const error = AuthError('requestFailed', null);
        expect(localizedAuthError(l10n, error), 'Request failed: ');
      });
    });

    group('profileUpdateFailed', () {
      test('returns localized message with detail', () {
        const error = AuthError('profileUpdateFailed', 'Email in use');
        expect(
          localizedAuthError(l10n, error),
          'Profile update failed: Email in use',
        );
      });
    });

    group('deleteAccountFailed', () {
      test('returns localized message with detail', () {
        const error = AuthError('deleteAccountFailed', 'Cannot delete admin');
        expect(
          localizedAuthError(l10n, error),
          'Delete account failed: Cannot delete admin',
        );
      });
    });

    group('forgotPasswordFailed', () {
      test('returns localized message with detail', () {
        const error = AuthError('forgotPasswordFailed', 'Server error');
        expect(
          localizedAuthError(l10n, error),
          'Forgot password failed: Server error',
        );
      });
    });

    group('passwordResetTokenInvalid', () {
      test('returns detail when present', () {
        const error = AuthError('passwordResetTokenInvalid', 'Token expired');
        expect(localizedAuthError(l10n, error), 'Token expired');
      });

      test('returns fallback when detail is null', () {
        const error = AuthError('passwordResetTokenInvalid', null);
        expect(
          localizedAuthError(l10n, error),
          'Invalid or expired reset token',
        );
      });
    });

    group('passwordResetFailed', () {
      test('returns localized message with detail', () {
        const error = AuthError('passwordResetFailed', 'Network error');
        expect(
          localizedAuthError(l10n, error),
          'Password reset failed: Network error',
        );
      });
    });

    group('server and unknown codes', () {
      test('returns detail for server code', () {
        const error = AuthError('server', 'Internal server error');
        expect(localizedAuthError(l10n, error), 'Internal server error');
      });

      test('returns detail for unknown code', () {
        const error = AuthError('unknownCode', 'Some error');
        expect(localizedAuthError(l10n, error), 'Some error');
      });

      test('returns empty string when detail is null for server code', () {
        const error = AuthError('server', null);
        expect(localizedAuthError(l10n, error), '');
      });

      test('returns empty string when detail is null for unknown code', () {
        const error = AuthError('unknownCode', null);
        expect(localizedAuthError(l10n, error), '');
      });
    });
  });
}
