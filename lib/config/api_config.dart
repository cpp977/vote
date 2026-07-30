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
  /// Base URL for the backend API server.
  ///
  /// Configured via pubspec.yaml dart_define section.
  /// Defaults to `http://127.0.0.1:8848` for local development.
  static const String baseUrl = Dartdefine.apiBaseUrl;
}
