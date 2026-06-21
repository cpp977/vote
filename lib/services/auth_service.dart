import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/auth_models.dart';

/// Service for making authentication-related API calls.
class AuthService {
  static const String _baseUrl = 'http://127.0.0.1:8848';

  /// Registers a new user.
  /// Returns the created [User] on success.
  /// Throws [ApiException] on failure.
  Future<User> register(RegisterRequest request) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/register'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(request.toJson()),
    );

    if (response.statusCode == 201) {
      return User.fromJson(jsonDecode(response.body));
    } else {
      final error = _parseError(response);
      throw ApiException(error, response.statusCode);
    }
  }

  /// Logs in a user.
  /// Returns [AuthResponse] with tokens on success.
  /// Throws [ApiException] on failure.
  Future<AuthResponse> login(LoginRequest request) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(request.toJson()),
    );

    if (response.statusCode == 200) {
      return AuthResponse.fromJson(jsonDecode(response.body));
    } else {
      final error = _parseError(response);
      throw ApiException(error, response.statusCode);
    }
  }

  /// Logs out a user by revoking the refresh token.
  Future<void> logout(LogoutRequest request, String accessToken) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/logout'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $accessToken',
      },
      body: jsonEncode(request.toJson()),
    );

    if (response.statusCode != 200 && response.statusCode != 204) {
      final body = response.body;
      if (body.isEmpty) {
        throw ApiException('Logout failed with status ${response.statusCode}', response.statusCode);
      }
      final error = ApiError.fromJson(jsonDecode(body));
      throw ApiException(error.error, response.statusCode);
    }
  }

  /// Refreshes the token pair using a valid refresh token.
  /// Returns a new [AuthResponse] with fresh tokens.
  /// Throws [ApiException] on failure.
  Future<AuthResponse> refresh(RefreshRequest request) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/refresh'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(request.toJson()),
    );

    if (response.statusCode == 200) {
      return AuthResponse.fromJson(jsonDecode(response.body));
    } else {
      final error = _parseError(response);
      throw ApiException(error, response.statusCode);
    }
  }

  /// Parses an error message from an API response.
  /// Handles empty response bodies gracefully.
  String _parseError(http.Response response) {
    final body = response.body;
    if (body.isEmpty) {
      return 'Request failed with status ${response.statusCode}';
    }
    try {
      final error = ApiError.fromJson(jsonDecode(body));
      return error.error;
    } catch (_) {
      return body;
    }
  }
}

/// Exception thrown when an API call fails.
class ApiException implements Exception {
  final String message;
  final int statusCode;

  const ApiException(this.message, this.statusCode);

  @override
  String toString() => 'ApiException($statusCode): $message';
}
