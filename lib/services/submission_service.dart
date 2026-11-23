import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:vote/config/api_config.dart';
import 'package:vote/models/submission_models.dart';
import 'package:vote/services/auth_middleware.dart';
import 'package:vote/utils/constants.dart';

/// Exception thrown when a submission-related API call fails.
class SubmissionException implements Exception {
  final String message;
  final int? statusCode;

  const SubmissionException(this.message, [this.statusCode]);

  @override
  String toString() => 'SubmissionException($statusCode): $message';
}

/// Service for the question-submission workflow:
///  - [getMySubmissions] lists the authenticated user's own submissions
///    (any status) via `GET /questions/mine`.
///  - [submitQuestion] creates a new submission on behalf of the authenticated
///    user via `POST /questions/submissions`; the question is submitted together
///    with its answer options (both optional) and the backend stores them
///    atomically as `pending`.
///  - [submitAnswerOption] proposes a new answer option for an existing
///    question via `POST /questions/{id}/answer-submissions`, stored as
///    `pending` until an administrator approves it.
///  - [getMyAnswerSubmissions] lists the authenticated user's own answer-option
///    submissions via `GET /answer-submissions/mine`.
///
/// Requests go through [AuthMiddleware] so expired access tokens are refreshed
/// transparently and retried.
class SubmissionService {
  final AuthMiddleware _authMiddleware;

  SubmissionService({AuthMiddleware? authMiddleware})
    : _authMiddleware = authMiddleware ?? AuthMiddleware();

  /// Loads the authenticated user's own question submissions.
  ///
  /// Returns an empty list when the user has no submissions yet.
  /// Throws [SubmissionException] on failure. A `401` status is surfaced so the
  /// caller can route the user back to login.
  Future<List<Submission>> getMySubmissions() async {
    final response = await _authMiddleware.get(
      '${ApiConfig.baseUrl}/questions/mine',
    );
    if (response.statusCode == 200) {
      final List<dynamic> data =
          (jsonDecode(response.body) as List?) ?? <dynamic>[];
      return data
          .map((e) => Submission.fromJson(e as Map<String, dynamic>))
          .toList();
    } else if (response.statusCode == 401) {
      throw const SubmissionException('Unauthorized', 401);
    } else {
      throw SubmissionException(_parseError(response), response.statusCode);
    }
  }

  /// Creates a new question submission for the authenticated user.
  ///
  /// The submission is stored as `pending` server-side; clients cannot
  /// self-approve. [language] must be a 2-character code (e.g. `en`, `de`).
  /// The submitting user does not choose a minimum age; admins set it (and the
  /// special category) when approving. Both [categoryId] and [answerOptions]
  /// are optional: a submission without them is stored incomplete and has to be
  /// completed by an administrator before it may be approved. When
  /// [answerOptions] are given they must contain at least one non-empty answer
  /// and at most [kMaxAnswerOptions] (50); the backend inserts the question
  /// together with its answer options in a single transaction and rejects
  /// submissions with too many options.
  ///
  /// Returns the created [Submission] (status `pending`, including its
  /// [Submission.answerOptions]) on success.
  /// Throws [SubmissionException] on failure.
  Future<Submission> submitQuestion({
    required String text,
    int? categoryId,
    required String language,
    List<String> answerOptions = const <String>[],
  }) async {
    // Trim and drop empty entries so a submission never reaches the backend
    // with blank options.
    final cleanedOptions = answerOptions
        .map((o) => o.trim())
        .where((o) => o.isNotEmpty)
        .toList();
    final body = jsonEncode(<String, Object>{
      'text': text,
      'category_id': ?categoryId,
      'language': language,
      if (cleanedOptions.isNotEmpty) 'answer_options': cleanedOptions,
    });
    final response = await _authMiddleware.post(
      '${ApiConfig.baseUrl}/questions/submissions',
      body: body,
    );
    if (response.statusCode == 201) {
      return Submission.fromJson(
        jsonDecode(response.body) as Map<String, dynamic>,
      );
    } else if (response.statusCode == 401) {
      throw const SubmissionException('Unauthorized', 401);
    } else {
      throw SubmissionException(_parseError(response), response.statusCode);
    }
  }

  /// Proposes a new answer option for an existing question.
  ///
  /// The proposal is stored as `pending` server-side; an administrator has to
  /// approve it (which appends the option to the question) or reject it. The
  /// question must exist and be approved, otherwise the backend answers with
  /// `404`. [text] is trimmed and must be non-empty; the backend additionally
  /// caps it at 500 characters.
  ///
  /// Returns the created [AnswerSubmission] (status `pending`).
  /// Throws [SubmissionException] on failure.
  Future<AnswerSubmission> submitAnswerOption({
    required int questionId,
    required String text,
  }) async {
    final body = jsonEncode(<String, Object>{'text': text.trim()});
    final response = await _authMiddleware.post(
      '${ApiConfig.baseUrl}/questions/$questionId/answer-submissions',
      body: body,
    );
    if (response.statusCode == 201) {
      return AnswerSubmission.fromJson(
        jsonDecode(response.body) as Map<String, dynamic>,
      );
    } else if (response.statusCode == 401) {
      throw const SubmissionException('Unauthorized', 401);
    } else {
      throw SubmissionException(_parseError(response), response.statusCode);
    }
  }

  /// Loads the authenticated user's own answer-option submissions.
  ///
  /// [status] optionally filters by `pending`, `approved` or `rejected`;
  /// without it all of the caller's submissions are returned.
  /// Returns an empty list when the user has no submissions yet.
  /// Throws [SubmissionException] on failure. A `401` status is surfaced so the
  /// caller can route the user back to login.
  Future<List<AnswerSubmission>> getMyAnswerSubmissions({
    String? status,
  }) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}/answer-submissions/mine')
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
    } else if (response.statusCode == 401) {
      throw const SubmissionException('Unauthorized', 401);
    } else {
      throw SubmissionException(_parseError(response), response.statusCode);
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
