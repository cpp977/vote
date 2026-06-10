import 'package:http/http.dart' as http;
import '../models/auth_models.dart';
import 'auth_service.dart';
import 'token_storage.dart';

/// HTTP middleware that handles authentication token management.
///
/// Features:
/// - Automatically attaches Bearer token to requests
/// - Handles 401 responses by refreshing the token
/// - Retries failed requests with the new token
class AuthMiddleware {
  final AuthService _authService;
  final TokenStorage _tokenStorage;
  bool _isRefreshing = false;

  AuthMiddleware({
    AuthService? authService,
    TokenStorage? tokenStorage,
  })  : _authService = authService ?? AuthService(),
        _tokenStorage = tokenStorage ?? TokenStorage();

  /// Performs an authenticated GET request.
  /// Automatically handles token refresh on 401 responses.
  Future<http.Response> get(String url, {Map<String, String>? headers}) async {
    return _makeRequest(
      'GET',
      url,
      headers: headers,
    );
  }

  /// Performs an authenticated POST request.
  /// Automatically handles token refresh on 401 responses.
  Future<http.Response> post(
    String url, {
    Map<String, String>? headers,
    Object? body,
  }) async {
    return _makeRequest(
      'POST',
      url,
      headers: headers,
      body: body,
    );
  }

  /// Performs an authenticated PUT request.
  /// Automatically handles token refresh on 401 responses.
  Future<http.Response> put(
    String url, {
    Map<String, String>? headers,
    Object? body,
  }) async {
    return _makeRequest(
      'PUT',
      url,
      headers: headers,
      body: body,
    );
  }

  /// Performs an authenticated DELETE request.
  /// Automatically handles token refresh on 401 responses.
  Future<http.Response> delete(
    String url, {
    Map<String, String>? headers,
  }) async {
    return _makeRequest(
      'DELETE',
      url,
      headers: headers,
    );
  }

  Future<http.Response> _makeRequest(
    String method,
    String url, {
    Map<String, String>? headers,
    Object? body,
    bool isRetry = false,
  }) async {
    final token = await _tokenStorage.getAccessToken();
    final requestHeaders = <String, String>{
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
      ...?headers,
    };

    http.Response response;
    switch (method) {
      case 'GET':
        response = await http.get(Uri.parse(url), headers: requestHeaders);
        break;
      case 'POST':
        response = await http.post(Uri.parse(url), headers: requestHeaders, body: body);
        break;
      case 'PUT':
        response = await http.put(Uri.parse(url), headers: requestHeaders, body: body);
        break;
      case 'DELETE':
        response = await http.delete(Uri.parse(url), headers: requestHeaders);
        break;
      default:
        throw UnsupportedError('HTTP method $method not supported');
    }

    // If unauthorized and not already retrying, attempt token refresh
    if (response.statusCode == 401 && !isRetry) {
      final refreshed = await _refreshToken();
      if (refreshed) {
        // Retry the request with the new token
        return _makeRequest(method, url, headers: headers, body: body, isRetry: true);
      }
    }

    return response;
  }

  /// Attempts to refresh the access token using the stored refresh token.
  /// Returns true if successful, false otherwise.
  Future<bool> _refreshToken() async {
    if (_isRefreshing) {
      // Wait for the ongoing refresh to complete
      while (_isRefreshing) {
        await Future.delayed(const Duration(milliseconds: 100));
      }
      return await _tokenStorage.hasTokens();
    }

    _isRefreshing = true;
    try {
      final refreshToken = await _tokenStorage.getRefreshToken();
      if (refreshToken == null) {
        return false;
      }

      final request = RefreshRequest(refreshToken: refreshToken);
      final response = await _authService.refresh(request);

      await _tokenStorage.setAccessToken(response.accessToken);
      await _tokenStorage.setRefreshToken(response.refreshToken);

      return true;
    } on ApiException catch (e) {
      // If refresh fails with 401, tokens are invalid - clear them
      if (e.statusCode == 401) {
        await _tokenStorage.clearAll();
      }
      return false;
    } catch (_) {
      return false;
    } finally {
      _isRefreshing = false;
    }
  }
}
