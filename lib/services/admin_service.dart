import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:vote/config/api_config.dart';
import 'package:vote/models/auth_models.dart';
import 'package:vote/models/submission_models.dart';
import 'package:vote/services/auth_middleware.dart';

/// Exception thrown when an administrator API call fails.
class AdminException implements Exception {
  final String message;
  final int? statusCode;

  const AdminException(this.message, [this.statusCode]);

  @override
  String toString() => 'AdminException($statusCode): $message';
}

/// Service for administrator endpoints:
///  - [getSubmissions] lists every submission that is not yet approved via
///    `GET /admin/questions/submissions` (the review queue).
///  - [approveQuestion] marks a submission as `approved` (publicly visible)
///    through `POST /admin/questions/{id}/approve`.
///  - [rejectQuestion] marks a submission as `rejected` through
///    `POST /admin/questions/{id}/reject`.
///  - [getUsers] lists all registered users via `GET /admin/users`.
///  - [getUser] fetches detailed information for a single user via
///    `GET /admin/users/{id}`.
///  - [activateUser] reactivates a user via `POST /admin/users/{id}/active`.
///  - [deactivateUser] deactivates a user via `POST /admin/users/{id}/inactive`.
///
/// Requests go through [AuthMiddleware] so expired access tokens are refreshed
/// transparently and retried.
class AdminService {
  final AuthMiddleware _authMiddleware;

  AdminService({AuthMiddleware? authMiddleware})
    : _authMiddleware = authMiddleware ?? AuthMiddleware();

  /// Loads the full review queue (all submissions that are not yet approved).
  ///
  /// Returns an empty list when there are no submissions to review.
  /// Throws [AdminException] on failure. A `401`/`403` status is surfaced so
  /// the caller can route the user back to login.
  Future<List<Submission>> getSubmissions() async {
    final response = await _authMiddleware.get(
      '${ApiConfig.baseUrl}/admin/questions/submissions',
    );
    if (response.statusCode == 200) {
      final List<dynamic> data =
          (jsonDecode(response.body) as List?) ?? <dynamic>[];
      return data
          .map((e) => Submission.fromJson(e as Map<String, dynamic>))
          .toList();
    } else if (response.statusCode == 401 || response.statusCode == 403) {
      throw const AdminException('Unauthorized', 401);
    } else {
      throw AdminException(_parseError(response), response.statusCode);
    }
  }

  /// Approves the submission with the given [id], making it publicly visible.
  ///
  /// Returns the updated [Submission] (status `approved`).
  /// Throws [AdminException] on failure (including `401`/`403`).
  Future<Submission> approveQuestion(int id) async {
    return _review(
      '${ApiConfig.baseUrl}/admin/questions/$id/approve',
      'approve',
    );
  }

  /// Rejects the submission with the given [id].
  ///
  /// Returns the updated [Submission] (status `rejected`).
  /// Throws [AdminException] on failure (including `401`/`403`).
  Future<Submission> rejectQuestion(int id) async {
    return _review('${ApiConfig.baseUrl}/admin/questions/$id/reject', 'reject');
  }

  /// Lists all registered users via `GET /admin/users`.
  ///
  /// Returns a list of [User] objects containing at least `id` and
  /// `username`. Throws [AdminException] on failure (including `401`/`403`).
  Future<List<User>> getUsers() async {
    final response = await _authMiddleware.get(
      '${ApiConfig.baseUrl}/admin/users',
    );
    if (response.statusCode == 200) {
      final List<dynamic> data =
          (jsonDecode(response.body) as List?) ?? <dynamic>[];
      return data.map((e) => User.fromJson(e as Map<String, dynamic>)).toList();
    } else if (response.statusCode == 401 || response.statusCode == 403) {
      throw const AdminException('Unauthorized', 401);
    } else {
      throw AdminException(_parseError(response), response.statusCode);
    }
  }

  /// Fetches detailed information for the user with the given [id] via
  /// `GET /admin/users/{id}`.
  ///
  /// Returns the full [User] object (all fields except `password_hash`).
  /// Throws [AdminException] on failure (including `401`/`403`/`404`).
  Future<User> getUser(int id) async {
    final response = await _authMiddleware.get(
      '${ApiConfig.baseUrl}/admin/users/$id',
    );
    if (response.statusCode == 200) {
      return User.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
    } else if (response.statusCode == 401 || response.statusCode == 403) {
      throw const AdminException('Unauthorized', 401);
    } else if (response.statusCode == 404) {
      throw const AdminException('Not found', 404);
    } else {
      throw AdminException(_parseError(response), response.statusCode);
    }
  }

  /// Activates the user with the given [id] via
  /// `POST /admin/users/{id}/active`.
  ///
  /// Returns the updated [User] object with `isActive` set to `true`.
  /// Throws [AdminException] on failure (including `401`/`403`/`404`).
  Future<User> activateUser(int id) async {
    return _toggleActive(
      '${ApiConfig.baseUrl}/admin/users/$id/active',
      'activate',
    );
  }

  /// Deactivates the user with the given [id] via
  /// `POST /admin/users/{id}/inactive`.
  ///
  /// Returns the updated [User] object with `isActive` set to `false`.
  /// Throws [AdminException] on failure (including `401`/`403`/`404`).
  Future<User> deactivateUser(int id) async {
    return _toggleActive(
      '${ApiConfig.baseUrl}/admin/users/$id/inactive',
      'deactivate',
    );
  }

  /// Helper that sends a POST to [url] and parses the response as a [User].
  Future<User> _toggleActive(String url, String action) async {
    final response = await _authMiddleware.post(url);
    if (response.statusCode == 200) {
      return User.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
    } else if (response.statusCode == 401 || response.statusCode == 403) {
      throw const AdminException('Unauthorized', 401);
    } else if (response.statusCode == 404) {
      throw const AdminException('Not found', 404);
    } else {
      throw AdminException(_parseError(response), response.statusCode);
    }
  }

  Future<Submission> _review(String url, String action) async {
    final response = await _authMiddleware.post(url);
    if (response.statusCode == 200) {
      return Submission.fromJson(
        jsonDecode(response.body) as Map<String, dynamic>,
      );
    } else if (response.statusCode == 401 || response.statusCode == 403) {
      throw const AdminException('Unauthorized', 401);
    } else if (response.statusCode == 404) {
      throw const AdminException('Not found', 404);
    } else {
      throw AdminException(_parseError(response), response.statusCode);
    }
  }

  /// Extracts a human-readable error message from an error response body.
  String _parseError(http.Response response) {
    final body = response.body;
    if (body.isEmpty) {
      return 'Request failed with status ${response.statusCode}';
    }
    try {
      final data = jsonDecode(body);
      if (data is Map<String, dynamic> && data['error'] is String) {
        return data['error'] as String;
      }
    } catch (_) {
      // Fall back to the raw body below.
    }
    return body;
  }
}
