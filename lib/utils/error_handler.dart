import 'dart:async';
import 'dart:io';

import '../l10n/app_localizations.dart';

/// Categorises a non-`ApiException` thrown while talking to the backend,
/// so the UI can show a message that does not leak Dart-internal exception
/// text (e.g. `SocketException: Failed to connect...`).
enum ErrorType {
  /// The device has no route to the host — Wi-Fi / mobile-data is off or the
  /// network is unreachable.
  noConnection,

  /// The request did not complete within the time limit.
  timeout,

  /// A TLS/SSL handshake could not be completed.
  sslError,

  /// The response body could not be decoded as JSON.
  malformedResponse,

  /// Anything else that was not recognised as a transport-layer error.
  unknown,
}

/// Inspects [error] and returns the [ErrorType] that best describes it.
///
/// Network-related exceptions from `package:http` and the Dart SDK
/// (`SocketException`, `TimeoutException`, `HandshakeException`) are mapped
/// to their respective categories; everything else falls back to
/// [ErrorType.unknown] (or [ErrorType.malformedResponse] for
/// `FormatException`).
ErrorType classifyError(Object error) {
  if (error is SocketException) {
    return ErrorType.noConnection;
  }
  if (error is TimeoutException) {
    return ErrorType.timeout;
  }
  if (error is HandshakeException) {
    return ErrorType.sslError;
  }
  if (error is FormatException) {
    return ErrorType.malformedResponse;
  }
  return ErrorType.unknown;
}

/// Returns `true` when [error] represents a network-connectivity problem the
/// caller may want to surface with a dedicated UI (e.g. an offline banner).
bool isConnectivityError(Object error) {
  return error is SocketException;
}

/// Maps [error] to a short, user-facing, **localized** description.
///
/// Network and parsing failures are translated to stable, friendly strings
/// instead of the raw `toString()` of the underlying Dart exception. For
/// genuinely unexpected errors the [AppLocalizations.unknownError] fallback is
/// returned so an implementation detail is never shown directly to the user.
String localizedError(AppLocalizations l10n, Object error) {
  return switch (classifyError(error)) {
    ErrorType.noConnection => l10n.noInternetConnection,
    ErrorType.timeout => l10n.connectionTimeout,
    ErrorType.sslError => l10n.connectionFailedGeneric,
    ErrorType.malformedResponse => l10n.serverError,
    ErrorType.unknown => l10n.unknownError,
  };
}
