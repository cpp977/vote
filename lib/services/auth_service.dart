import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import '../models/auth_models.dart';
import '../models/category_models.dart';

/// Service for making authentication-related API calls.
class AuthService {
  static const String _baseUrl = ApiConfig.baseUrl;

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
      throw _parseError(response);
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
      throw _parseError(response);
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
        throw ApiException(
          'Logout failed with status ${response.statusCode}',
          response.statusCode,
          'logoutFailed',
        );
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
      throw _parseError(response);
    }
  }

  /// Fetches the current user's profile data.
  /// Returns [User] on success.
  /// Throws [ApiException] on failure.
  Future<User> getCurrentUser(String accessToken) async {
    final response = await http.get(
      Uri.parse('$_baseUrl/me'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $accessToken',
      },
    );

    if (response.statusCode == 200) {
      return User.fromJson(jsonDecode(response.body));
    } else {
      throw _parseError(response);
    }
  }

  /// Updates the current user's profile (email, gender and/or password) via
  /// the `PATCH /me` endpoint.
  ///
  /// [request] carries the fields to change; `username` is never modifiable.
  /// Returns the updated [User] on success.
  /// Throws [ApiException] on failure.
  Future<User> updateCurrentUser(
    String accessToken,
    UpdateUserRequest request,
  ) async {
    final response = await http.patch(
      Uri.parse('$_baseUrl/me'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $accessToken',
      },
      body: jsonEncode(request.toJson()),
    );

    if (response.statusCode == 200) {
      return User.fromJson(jsonDecode(response.body));
    } else {
      throw _parseError(response);
    }
  }

  /// Fetches the list of available question categories for the given
  /// [languageCode] (e.g. `en`, `de`).
  ///
  /// Uses the language-aware `GET /categories/lang/{languageCode}` endpoint so
  /// that only categories matching the user's locale are returned.
  ///
  /// Returns a [List<Category>] on success.
  /// Throws [ApiException] on failure.
  Future<List<Category>> getCategories(
    String accessToken,
    String languageCode,
  ) async {
    final response = await http.get(
      Uri.parse('$_baseUrl/categories/lang/$languageCode'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $accessToken',
      },
    );

    if (response.statusCode == 200) {
      final List<dynamic> data =
          (jsonDecode(response.body) as List?) ?? <dynamic>[];
      return data
          .map((e) => Category.fromJson(e as Map<String, dynamic>))
          .toList();
    } else {
      throw _parseError(response);
    }
  }

  /// Parses an API error into an [ApiException].
  ///
  /// When the body is empty/unparsable the [ApiException.code] is set to
  /// `requestFailed` so the UI can localize it with the HTTP status code.
  /// Otherwise the raw server message is preserved (code `null`).
  ApiException _parseError(http.Response response) {
    final body = response.body;
    if (body.isEmpty) {
      return ApiException(
        'Request failed with status ${response.statusCode}',
        response.statusCode,
        'requestFailed',
      );
    }
    try {
      final error = ApiError.fromJson(jsonDecode(body));
      return ApiException(error.error, response.statusCode);
    } catch (_) {
      return ApiException(body, response.statusCode);
    }
  }
}

/// Exception thrown when an API call fails.
class ApiException implements Exception {
  final String message;
  final int statusCode;
  final String? code;

  const ApiException(this.message, this.statusCode, [this.code]);

  @override
  String toString() => 'ApiException($statusCode): $message';
}
