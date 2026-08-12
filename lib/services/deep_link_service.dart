import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:uni_links/uni_links.dart';

/// Path segment of the deep-link URL that triggers the reset-password page.
///
/// The backend sends reset links as `https://vote.app/reset-password?token=…`.
/// Only links whose path is `/reset-password` are handled; all other incoming
/// URIs are ignored by this service.
const String kResetPasswordPath = '/reset-password';

/// Centralized deep-link handler that works across **mobile** (Android/iOS)
/// and **web** / **desktop**.
///
/// The service detects when the user opens a password-reset link — either
/// from a cold start (app was not running) or while the app is already in
/// the foreground — and extracts the `token` query parameter so the caller
/// can navigate to the [ResetPasswordPage].
///
/// ## Mobile (Android / iOS)
///
/// Uses [getInitialUri] for cold-start links and [uriLinkStream] for links
/// received while the app is running. Android App Links / iOS Universal Links
/// open the app directly when the scheme + host match an intent-filter
/// registered in the native manifest (see `AndroidManifest.xml`). If
/// verification fails, Android shows a disambiguation dialog — the link
/// still works.
///
/// ## Web / Linux / Windows
///
/// On these platforms the email link opens in the default browser (which
/// serves the Flutter web build). `Uri.base` is read once on startup to
/// obtain the token. No stream is needed because a navigation in the browser
/// always causes the page to reload.
class DeepLinkService {
  DeepLinkService._();

  /// The stream of incoming URIs while the app is in the foreground.
  ///
  /// On web this is always an empty stream (the web app reloads on every
  /// navigation, so the initial URI is sufficient). On mobile this emits
  /// each new link that the OS delivers to a running app instance.
  static Stream<Uri> get uriStream {
    if (kIsWeb) {
      return const Stream.empty();
    }
    // uriLinkStream is Stream<Uri?> — filter out nulls.
    return uriLinkStream.where((uri) => uri != null).cast<Uri>();
  }

  /// Retrieves the URI that launched the app (cold start) or the current
  /// browser URL (web / desktop).
  ///
  /// Returns `null` when the app was launched normally (no deep link) or
  /// when the platform does not support deep links.
  static Future<Uri?> getInitialUri() async {
    if (kIsWeb) {
      // On web, Uri.base reflects the current browser URL.
      final base = Uri.base;
      // Only return if the path looks like a deep link (non-root).
      if (base.path == '/' || base.path.isEmpty) {
        return null;
      }
      return base;
    }
    // On mobile, use uni_links to retrieve the launching URI.
    try {
      return getInitialUri();
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
  /// - every time a reset link is received while the app is running (mobile).
  ///
  /// Returns a [StreamSubscription] that should be cancelled (e.g. in a
  /// `dispose` method) to stop listening for new links, or `null` on web
  /// (where no stream subscription is needed).
  static Future<StreamSubscription<Uri?>?> init(
    void Function(String token) onResetTokenReceived,
  ) async {
    if (kIsWeb) {
      // Web: check the initial URL only.
      final uri = await getInitialUri();
      if (uri != null) {
        final token = extractResetToken(uri);
        if (token != null) {
          onResetTokenReceived(token);
        }
      }
      return null;
    }

    // Mobile: check the initial URI (cold start) and listen to the stream.
    final uri = await getInitialUri();
    if (uri != null) {
      final token = extractResetToken(uri);
      if (token != null) {
        onResetTokenReceived(token);
      }
    }

    // Listen for links received while the app is already running.
    return uriLinkStream.listen((Uri? incomingUri) {
      if (incomingUri == null) return;
      final token = extractResetToken(incomingUri);
      if (token != null) {
        onResetTokenReceived(token);
      }
    });
  }
}
