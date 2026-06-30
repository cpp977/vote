/// Centralized API configuration.
///
/// All backend URLs should reference [ApiConfig.baseUrl] instead of
/// hardcoding the host, port, or scheme.
class ApiConfig {
  /// Base URL for the backend API server.
  static const String baseUrl = 'http://127.0.0.1:8848';
}
