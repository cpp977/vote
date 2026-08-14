import 'dart:async';

import 'package:app_links/app_links.dart';

/// Path segment of the deep-link URL that triggers the reset-password page.
///
/// The backend sends reset links as `https://vote.app/reset-password?token=…`.
/// Only links whose path is `/reset-password` are handled; all other incoming
/// URIs are ignored by this service.
const String kResetPasswordPath = '/reset-password';

/// Centralized deep-link handler that works across **mobile**, **web**, and
/// **desktop** (including Linux) via `package:app_links`.
///
/// The service detects when the user opens a password-reset link — either
/// from a cold start (app was not running) or while the app is already in
/// the foreground — and extracts the `token` query parameter so the caller
/// can navigate to the [ResetPasswordPage].
///
/// `app_links` provides a single, unified API across all platforms:
/// [AppLinks.getInitialAppLink] for cold-start links, and
/// [AppLinks.uriLinkStream] for links received while the app is running.
/// The plugin handles the web/desktop/mobile differences internally, so
/// this service no longer needs to branch on `kIsWeb` or platform checks.
class DeepLinkService {
  DeepLinkService._();

  /// Singleton instance. Created lazily on first access.
  ///
  /// Per the `app_links` docs, this should be instantiated as early as
  /// possible so the very first cold-start link isn't missed.
  static final AppLinks _appLinks = AppLinks();

  /// The stream of incoming URIs while the app is in the foreground.
  static Stream<Uri> get uriStream => _appLinks.uriLinkStream;

  /// Retrieves the URI that launched the app (cold start), or `null` if the
  /// app was launched normally (no deep link).
  static Future<Uri?> getInitialUri() async {
    try {
      return await _appLinks.getInitialLink();
    } catch (_) {
      return null;
    }
  }

  /// Extracts the password-reset token from [uri] if it is a valid
  /// reset-password link.
  ///
  /// Returns the raw token string, or `null` if the URI does not target
  /// the reset-password path or does not contain a `token` query parameter.
  static String? extractResetToken(Uri uri) {
    // Normalize the path — strip trailing slashes so `/reset-password/`
    // still matches.
    final path = uri.path.replaceAll(RegExp(r'/+$'), '');
    if (path != kResetPasswordPath) {
      return null;
    }
    final token = uri.queryParameters['token'];
    if (token == null || token.isEmpty) {
      return null;
    }
    return token;
  }

  /// Initializes deep-link handling and registers a callback that is invoked
  /// whenever a reset-password link is detected.
  ///
  /// The [onResetTokenReceived] callback receives the raw token string. It is
  /// called:
  /// - once on startup if the app was launched from a reset link (cold start),
  /// - every time a reset link is received while the app is running.
  ///
  /// Returns a [StreamSubscription] that should be cancelled (e.g. in a
  /// `dispose` method) to stop listening for new links.
  static Future<StreamSubscription<Uri>> init(
    void Function(String token) onResetTokenReceived,
  ) async {
    // Check the initial URI (cold start).
    final uri = await getInitialUri();
    if (uri != null) {
      final token = extractResetToken(uri);
      if (token != null) {
        onResetTokenReceived(token);
      }
    }

    // Listen for links received while the app is already running.
    return uriStream.listen((Uri incomingUri) {
      final token = extractResetToken(incomingUri);
      if (token != null) {
        onResetTokenReceived(token);
      }
    });
  }
}
