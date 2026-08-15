import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart' hide Category;
import '../config/api_config.dart';
import '../models/auth_models.dart';
import '../models/category_models.dart';

/// Service for making authentication-related API calls.
class AuthService {
  static final String _baseUrl = ApiConfig.baseUrl;

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

  /// Requests a password-reset link by submitting the user's [email].
  ///
  /// The endpoint always returns the same generic success response regardless
  /// of whether the email belongs to an account — preventing user enumeration.
  ///
  /// Returns the server's [ForgotPasswordResponse] message on success (HTTP 200).
  /// Throws [ApiException] on failure (e.g. invalid email format → HTTP 400).
  Future<ForgotPasswordResponse> forgotPassword(
    ForgotPasswordRequest request,
  ) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/user/password/forgot'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(request.toJson()),
    );

    if (response.statusCode == 200) {
      return ForgotPasswordResponse.fromJson(jsonDecode(response.body));
    } else {
      throw _parseError(response);
    }
  }

  /// Consumes a password-reset [token] together with a new [password].
  ///
  /// The backend validates the token (single-use, time-limited, attempt
  /// counter) and atomically updates the user's password hash, marks the
  /// token as used, and revokes all refresh tokens.
  ///
  /// Throws [ApiException] on failure (invalid/expired/used token, password
  /// too short, max attempts exceeded, or DB error).
  Future<void> resetPassword(String token, String password) async {
    final request = ResetPasswordRequest(token: token, password: password);
    final response = await http.post(
      Uri.parse('$_baseUrl/user/password/reset'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(request.toJson()),
    );

    if (response.statusCode == 200) {
      return;
    } else {
      throw _parseError(response);
    }
  }

  /// Fetches the list of available question categories for the given
  ///
  /// Uses the language-aware `GET /categories/lang/{languageCode}` endpoint so
  /// that only categories matching the user's locale are returned.
  /// The endpoint is public; [accessToken] is optional and only used when
  /// present.
  ///
  /// Returns a [List<Category>] on success.
  /// Throws [ApiException] on failure.
  Future<List<Category>> getCategories(
    String languageCode, {
    String? accessToken,
  }) async {
    final headers = <String, String>{
      'Content-Type': 'application/json',
      if (accessToken != null) 'Authorization': 'Bearer $accessToken',
    };
    final response = await http.get(
      Uri.parse('$_baseUrl/categories/lang/$languageCode'),
      headers: headers,
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

  /// Deletes the authenticated user's account via the `/users/me/delete`
  /// endpoint. Throws [ApiException] on failure.
  Future<void> deleteAccount(String accessToken) async {
    debugPrint(
      'AuthService.deleteAccount: calling DELETE $_baseUrl/users/me/delete',
    );
    final response = await http.delete(
      Uri.parse('$_baseUrl/users/me/delete'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $accessToken',
      },
    );

    debugPrint(
      'AuthService.deleteAccount: response status ${response.statusCode}',
    );

    if (response.statusCode != 200 && response.statusCode != 204) {
      final body = response.body;
      if (body.isEmpty) {
        throw ApiException(
          'Delete failed with status ${response.statusCode}',
          response.statusCode,
          'deleteFailed',
        );
      }
      final error = ApiError.fromJson(jsonDecode(body));
      throw ApiException(error.error, response.statusCode);
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
