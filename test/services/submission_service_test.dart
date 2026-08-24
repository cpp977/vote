import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:vote/services/auth_middleware.dart';
import 'package:vote/services/submission_service.dart';

/// A recorded request captured by [_CapturingAuthMiddleware].
class _CapturedRequest {
  final String method;
  final String url;
  final Object? body;

  const _CapturedRequest(this.method, this.url, this.body);

  /// The JSON-decoded [body], or an empty map when no body was sent.
  Map<String, dynamic> get jsonBody => body is String
      ? jsonDecode(body as String) as Map<String, dynamic>
      : <String, dynamic>{};
}

/// [AuthMiddleware] double that records requests and answers with a canned
/// response, so the service layer can be tested without real HTTP.
class _CapturingAuthMiddleware extends AuthMiddleware {
  _CapturingAuthMiddleware({
    this.statusCode = 201,
    Map<String, dynamic>? responseBody,
  }) : responseBody = responseBody ?? _minimalSubmission;

  /// Minimal payload every endpoint of the service can decode; individual
  /// tests override it when they inspect the parsed result.
  static const Map<String, dynamic> _minimalSubmission = {
    'id': 1,
    'text': 'Question?',
    'category_id': 1,
  };

  final List<_CapturedRequest> requests = [];
  int statusCode;
  Map<String, dynamic> responseBody;

  @override
  Future<http.Response> post(
    String url, {
    Map<String, String>? headers,
    Object? body,
  }) async {
    requests.add(_CapturedRequest('POST', url, body));
    return http.Response(jsonEncode(responseBody), statusCode);
  }
}

const _createdSubmission = <String, dynamic>{
  'id': 9,
  'text': 'Question?',
  'category_id': 2,
  'language': 'en',
  'min_age': 0,
  'created_at': '2026-08-24T10:00:00Z',
  'special_category': 'none',
  'submission_status': 'pending',
  'answer_options': [
    {'id': 1, 'question_id': 9, 'text': 'Yes'},
    {'id': 2, 'question_id': 9, 'text': 'No'},
  ],
};

void main() {
  group('SubmissionService.submitQuestion', () {
    test(
      'posts the submission without min_age to /questions/submissions',
      () async {
        final middleware = _CapturingAuthMiddleware();
        final service = SubmissionService(authMiddleware: middleware);

        await service.submitQuestion(
          text: 'Is this a good question?',
          categoryId: 2,
          language: 'en',
          answerOptions: ['Yes', 'No'],
        );

        expect(middleware.requests, hasLength(1));
        final request = middleware.requests.single;
        expect(request.url, endsWith('/questions/submissions'));
        // The backend rejects submissions carrying min_age with 400, so the
        // body must consist of exactly these four fields.
        expect(request.jsonBody, {
          'text': 'Is this a good question?',
          'category_id': 2,
          'language': 'en',
          'answer_options': ['Yes', 'No'],
        });
      },
    );

    test('trims options and drops blank entries before sending', () async {
      final middleware = _CapturingAuthMiddleware();
      final service = SubmissionService(authMiddleware: middleware);

      await service.submitQuestion(
        text: 'Question?',
        categoryId: 1,
        language: 'en',
        answerOptions: ['  Yes ', '', ' No\t'],
      );

      expect(middleware.requests.single.jsonBody['answer_options'], [
        'Yes',
        'No',
      ]);
    });

    test(
      'throws and never contacts the backend without usable options',
      () async {
        final middleware = _CapturingAuthMiddleware();
        final service = SubmissionService(authMiddleware: middleware);

        await expectLater(
          service.submitQuestion(
            text: 'Question?',
            categoryId: 1,
            language: 'en',
            answerOptions: ['', '   '],
          ),
          throwsA(
            isA<SubmissionException>().having(
              (e) => e.message,
              'message',
              'At least one answer option is required',
            ),
          ),
        );
        expect(middleware.requests, isEmpty);
      },
    );

    test('parses the created submission from the 201 response', () async {
      final middleware = _CapturingAuthMiddleware(
        responseBody: _createdSubmission,
      );
      final service = SubmissionService(authMiddleware: middleware);

      final submission = await service.submitQuestion(
        text: 'Question?',
        categoryId: 2,
        language: 'en',
        answerOptions: ['Yes', 'No'],
      );

      expect(submission.id, 9);
      expect(submission.submissionStatus, 'pending');
      expect(submission.answerOptions, hasLength(2));
    });

    test('surfaces 401 as a SubmissionException with status code', () async {
      final middleware = _CapturingAuthMiddleware(
        statusCode: 401,
        responseBody: {'error': 'Unauthenticated'},
      );
      final service = SubmissionService(authMiddleware: middleware);

      await expectLater(
        service.submitQuestion(
          text: 'Question?',
          categoryId: 1,
          language: 'en',
          answerOptions: ['Yes'],
        ),
        throwsA(
          isA<SubmissionException>().having(
            (e) => e.statusCode,
            'statusCode',
            401,
          ),
        ),
      );
    });
  });
}
