import '../gen/dart_define.gen.dart';

/// Centralized API configuration.
///
/// All backend URLs should reference [ApiConfig.baseUrl] instead of
/// hardcoding the host, port, or scheme.
///
/// Configuration is managed via `pubspec.yaml` dart_define section.
/// The dart_define package generates typed constants from the configuration.
///
/// **Build commands:**
/// - Development: `flutter run --flavor dev`
/// - Production: `flutter run --flavor prod`
class ApiConfig {
  static final String baseUrl = Dartdefine.apiBaseUrl.isEmpty
      ? _defaultBaseUrl
      : Dartdefine.apiBaseUrl;

  static final String _defaultBaseUrl = switch (Dartdefine.flavor) {
    Flavor.development => 'https://vote-backend.local:8443',
    Flavor.production => 'https://vote-backend.duckdns.org:8443',
  };
}
