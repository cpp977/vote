import 'app_localizations.dart';
import '../models/auth_models.dart';

/// Resolves a localized, user-facing message for the given [AuthError].
///
/// The [AuthError.code] selects the template and [AuthError.detail] (when
/// present) is inserted into it:
/// - `loginFailed` / `registrationFailed`: wraps the underlying detail.
/// - `requestFailed`: shows the HTTP status code.
/// - `server` (and any unknown code): shows the raw server message as-is.
String localizedAuthError(AppLocalizations l10n, AuthError? error) {
  if (error == null) return '';
  switch (error.code) {
    case 'loginFailed':
      return l10n.loginFailed(error.detail ?? '');
    case 'registrationFailed':
      return l10n.registrationFailed(error.detail ?? '');
    case 'requestFailed':
      return l10n.requestFailedStatus(error.detail ?? '');
    case 'server':
    default:
      return error.detail ?? '';
  }
}
