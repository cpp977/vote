import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:vote/models/special_category.dart';
import 'package:vote/services/admin_service.dart';
import 'package:vote/services/auth_middleware.dart';

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
    this.statusCode = 200,
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

const _approvedSubmission = <String, dynamic>{
  'id': 5,
  'text': 'Question?',
  'category_id': 1,
  'language': 'en',
  'min_age': 18,
  'created_at': '2026-08-24T10:00:00Z',
  'special_category': 'health',
  'submission_status': 'approved',
};

void main() {
  group('AdminService.approveQuestion', () {
    test('sends min_age and the special_category label in the body', () async {
      final middleware = _CapturingAuthMiddleware(
        responseBody: _approvedSubmission,
      );
      final service = AdminService(authMiddleware: middleware);

      await service.approveQuestion(
        5,
        minAge: 18,
        specialCategory: SpecialCategory.health,
      );

      expect(middleware.requests, hasLength(1));
      final request = middleware.requests.single;
      expect(request.url, endsWith('/admin/questions/5/approve'));
      expect(request.jsonBody, {'min_age': 18, 'special_category': 'health'});
    });

    test('sends an empty body when no overrides are given', () async {
      final middleware = _CapturingAuthMiddleware();
      final service = AdminService(authMiddleware: middleware);

      await service.approveQuestion(5);

      // The backend treats an empty object as "use the defaults"
      // (min_age = 0, special_category = 'none').
      expect(middleware.requests.single.jsonBody, isEmpty);
    });

    test('encodes every category label verbatim', () async {
      for (final category in SpecialCategory.values) {
        final middleware = _CapturingAuthMiddleware();
        final service = AdminService(authMiddleware: middleware);

        await service.approveQuestion(1, specialCategory: category);

        expect(
          middleware.requests.single.jsonBody['special_category'],
          category.label,
          reason: '${category.name} should send its database label',
        );
      }
    });

    test('parses the approved submission from the response', () async {
      final middleware = _CapturingAuthMiddleware(
        responseBody: _approvedSubmission,
      );
      final service = AdminService(authMiddleware: middleware);

      final submission = await service.approveQuestion(5, minAge: 18);

      expect(submission.id, 5);
      expect(submission.isApproved, isTrue);
      expect(submission.minAge, 18);
    });
  });

  group('AdminService.rejectQuestion', () {
    test('posts to the reject endpoint without a body', () async {
      final middleware = _CapturingAuthMiddleware();
      final service = AdminService(authMiddleware: middleware);

      await service.rejectQuestion(7);

      final request = middleware.requests.single;
      expect(request.url, endsWith('/admin/questions/7/reject'));
      // Rejection must not carry approval settings.
      expect(request.body, isNull);
    });
  });

  group('AdminService error handling', () {
    test('surfaces backend validation errors on 400', () async {
      final middleware = _CapturingAuthMiddleware(
        statusCode: 400,
        responseBody: {'error': 'Unknown value for field \'special_category\''},
      );
      final service = AdminService(authMiddleware: middleware);

      await expectLater(
        service.approveQuestion(5, specialCategory: SpecialCategory.none),
        throwsA(
          isA<AdminException>()
              .having(
                (e) => e.message,
                'message',
                "Unknown value for field 'special_category'",
              )
              .having((e) => e.statusCode, 'statusCode', 400),
        ),
      );
    });
  });
}
