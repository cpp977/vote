import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:vote/config/api_config.dart';
import 'package:vote/models/auth_models.dart';
import 'package:vote/models/special_category.dart';
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
///    through `POST /admin/questions/{id}/approve`; it also assigns the
///    category and the answer options an admin completes for submissions that
///    were filed without them.
///  - [rejectQuestion] marks a submission as `rejected` through
///    `POST /admin/questions/{id}/reject`.
///  - [getAnswerSubmissions] lists every answer-option submission that is not
///    yet approved via `GET /admin/answer-submissions`.
///  - [approveAnswerSubmission] appends a proposed answer option to its
///    question via `POST /admin/answer-submissions/{id}/approve`.
///  - [rejectAnswerSubmission] marks an answer-option submission as `rejected`
///    through `POST /admin/answer-submissions/{id}/reject`.
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

  /// Loads the full review queue (all submissions that are not yet approved)
  /// via `GET /admin/questions/submissions`.
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
  /// The approving admin sets the [minAge] restriction (integer 0–120,
  /// defaulting to 0 = no restriction server-side) and the GDPR
  /// [specialCategory] (defaulting to [SpecialCategory.none]); both are sent
  /// in the request body and stored on the approved question.
  ///
  /// [categoryId] assigns a category to submissions that were filed without
  /// one, and [answerOptions] fills in answers for submissions that arrived
  /// with none; an approved question always needs both, so the backend rejects
  /// an approval that would leave either empty. [answerOptions] must not be
  /// sent for a question that already has answers.
  ///
  /// Returns the updated [Submission] (status `approved`).
  /// Throws [AdminException] on failure (including `401`/`403`).
  Future<Submission> approveQuestion(
    int id, {
    int? minAge,
    SpecialCategory? specialCategory,
    int? categoryId,
    List<String>? answerOptions,
  }) async {
    return _review(
      '${ApiConfig.baseUrl}/admin/questions/$id/approve',
      'approve',
      body: {
        'min_age': ?minAge,
        'special_category': ?specialCategory?.label,
        'category_id': ?categoryId,
        if (answerOptions != null && answerOptions.isNotEmpty)
          'answer_options': answerOptions,
      },
    );
  }

  /// Rejects the submission with the given [id].
  ///
  /// Returns the updated [Submission] (status `rejected`).
  /// Throws [AdminException] on failure (including `401`/`403`).
  Future<Submission> rejectQuestion(int id) async {
    return _review('${ApiConfig.baseUrl}/admin/questions/$id/reject', 'reject');
  }

  /// Loads the answer-option review queue (all submissions that are not yet
  /// approved) via `GET /admin/answer-submissions`.
  ///
  /// [status] optionally filters by `pending` or `rejected`; without it the
  /// full queue is returned. Returns an empty list when there is nothing to
  /// review. Throws [AdminException] on failure (including `401`/`403`).
  Future<List<AnswerSubmission>> getAnswerSubmissions({String? status}) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}/admin/answer-submissions')
        .replace(
          queryParameters: status == null
              ? null
              : <String, String>{'status': status},
        );
    final response = await _authMiddleware.get(uri.toString());
    if (response.statusCode == 200) {
      final List<dynamic> data =
          (jsonDecode(response.body) as List?) ?? <dynamic>[];
      return data
          .map((e) => AnswerSubmission.fromJson(e as Map<String, dynamic>))
          .toList();
    } else if (response.statusCode == 401 || response.statusCode == 403) {
      throw const AdminException('Unauthorized', 401);
    } else {
      throw AdminException(_parseError(response), response.statusCode);
    }
  }

  /// Approves the answer-option submission with the given [id]: the proposed
  /// option is appended to its question and becomes votable.
  ///
  /// Returns the updated [AnswerSubmission] (status `approved`).
  /// Throws [AdminException] on failure (including `401`/`403`/`404`/`409`).
  Future<AnswerSubmission> approveAnswerSubmission(int id) async {
    return _reviewAnswerSubmission(
      '${ApiConfig.baseUrl}/admin/answer-submissions/$id/approve',
    );
  }

  /// Rejects the answer-option submission with the given [id].
  ///
  /// Returns the updated [AnswerSubmission] (status `rejected`).
  /// Throws [AdminException] on failure (including `401`/`403`/`404`/`409`).
  Future<AnswerSubmission> rejectAnswerSubmission(int id) async {
    return _reviewAnswerSubmission(
      '${ApiConfig.baseUrl}/admin/answer-submissions/$id/reject',
    );
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
  Future<User> getUser(String id) async {
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
  Future<User> activateUser(String id) async {
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
  Future<User> deactivateUser(String id) async {
    return _toggleActive(
      '${ApiConfig.baseUrl}/admin/users/$id/inactive',
      'deactivate',
    );
  }

  /// Deletes the question with the given [id] via
  /// `POST /admin/questions/{id}/delete`.
  ///
  /// Throws [AdminException] on failure (including `401`/`403`/`404`).
  Future<void> deleteQuestion(int id) async {
    final response = await _authMiddleware.post(
      '${ApiConfig.baseUrl}/admin/questions/$id/delete',
    );
    if (response.statusCode == 200 || response.statusCode == 204) {
      return;
    } else if (response.statusCode == 401 || response.statusCode == 403) {
      throw const AdminException('Unauthorized', 401);
    } else if (response.statusCode == 404) {
      throw const AdminException('Not found', 404);
    } else {
      throw AdminException(_parseError(response), response.statusCode);
    }
  }

  /// Changes the question text with the given [id] via
  /// `PATCH /admin/questions/{id}/change`.
  ///
  /// Throws [AdminException] on failure (including `401`/`403`/`404`).
  Future<void> changeQuestionText(int id, String newText) async {
    final body = jsonEncode({'text': newText});
    final response = await _authMiddleware.patch(
      '${ApiConfig.baseUrl}/admin/questions/$id/change',
      body: body,
    );
    if (response.statusCode == 200) {
      return;
    } else if (response.statusCode == 401 || response.statusCode == 403) {
      throw const AdminException('Unauthorized', 401);
    } else if (response.statusCode == 404) {
      throw const AdminException('Not found', 404);
    } else if (response.statusCode == 400) {
      throw AdminException(_parseError(response), response.statusCode);
    } else {
      throw AdminException(_parseError(response), response.statusCode);
    }
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

  Future<Submission> _review(
    String url,
    String action, {
    Map<String, Object?>? body,
  }) async {
    final response = await _authMiddleware.post(
      url,
      body: body == null ? null : jsonEncode(body),
    );
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

  /// Sends a POST to [url] and parses the response as an [AnswerSubmission].
  Future<AnswerSubmission> _reviewAnswerSubmission(String url) async {
    final response = await _authMiddleware.post(url);
    if (response.statusCode == 200) {
      return AnswerSubmission.fromJson(
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
