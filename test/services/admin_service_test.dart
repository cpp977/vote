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
  _CapturingAuthMiddleware({this.statusCode = 200, dynamic responseBody})
    : _responseBody = responseBody ?? _minimalSubmission;

  /// Minimal payload every endpoint of the service can decode; individual
  /// tests override it when they inspect the parsed result.
  static const Map<String, dynamic> _minimalSubmission = {
    'id': 1,
    'text': 'Question?',
    'category_id': 1,
  };

  final List<_CapturedRequest> requests = [];
  int statusCode;
  final dynamic _responseBody;

  dynamic get responseBody => _responseBody;

  @override
  Future<http.Response> get(String url, {Map<String, String>? headers}) async {
    requests.add(_CapturedRequest('GET', url, null));
    return http.Response(jsonEncode(responseBody), statusCode);
  }

  @override
  Future<http.Response> post(
    String url, {
    Map<String, String>? headers,
    Object? body,
  }) async {
    requests.add(_CapturedRequest('POST', url, body));
    return http.Response(jsonEncode(responseBody), statusCode);
  }

  @override
  Future<http.Response> delete(
    String url, {
    Map<String, String>? headers,
  }) async {
    requests.add(_CapturedRequest('DELETE', url, null));
    return http.Response(jsonEncode(responseBody), statusCode);
  }

  @override
  Future<http.Response> patch(
    String url, {
    Map<String, String>? headers,
    Object? body,
  }) async {
    requests.add(_CapturedRequest('PATCH', url, body));
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

const _testUser = <String, dynamic>{
  'id': 'a1b2c3d4-e5f6-7890-abcd-ef1234567890',
  'username': 'testuser',
  'email': 'test@example.com',
  'birth_year': 1990,
  'gender': 'f',
  'nationality': 'US',
  'is_admin': false,
  'is_active': true,
};

const _testSubmission = <String, dynamic>{
  'id': 1,
  'text': 'Test question?',
  'category_id': 2,
  'language': 'en',
  'min_age': 0,
  'created_at': '2026-08-24T10:00:00Z',
  'special_category': 'none',
  'submission_status': 'pending',
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

  group('AdminService.getSubmissions', () {
    test('returns list of submissions on 200', () async {
      final middleware = _CapturingAuthMiddleware(
        responseBody: [_testSubmission, _approvedSubmission],
      );
      final service = AdminService(authMiddleware: middleware);

      final submissions = await service.getSubmissions();

      expect(submissions, hasLength(2));
      expect(submissions[0].id, 1);
      expect(submissions[0].text, 'Test question?');
      expect(submissions[1].id, 5);
      expect(submissions[1].isApproved, isTrue);
      expect(middleware.requests, hasLength(1));
      expect(middleware.requests.single.method, 'GET');
      expect(
        middleware.requests.single.url,
        endsWith('/admin/questions/submissions'),
      );
    });

    test('returns empty list when no submissions', () async {
      final middleware = _CapturingAuthMiddleware(responseBody: []);
      final service = AdminService(authMiddleware: middleware);

      final submissions = await service.getSubmissions();

      expect(submissions, isEmpty);
    });

    test('throws AdminException on 401', () async {
      final middleware = _CapturingAuthMiddleware(
        statusCode: 401,
        responseBody: {'error': 'Unauthorized'},
      );
      final service = AdminService(authMiddleware: middleware);

      await expectLater(
        service.getSubmissions(),
        throwsA(
          isA<AdminException>().having((e) => e.statusCode, 'statusCode', 401),
        ),
      );
    });

    test('throws AdminException on 403', () async {
      final middleware = _CapturingAuthMiddleware(
        statusCode: 403,
        responseBody: {'error': 'Forbidden'},
      );
      final service = AdminService(authMiddleware: middleware);

      await expectLater(
        service.getSubmissions(),
        throwsA(
          isA<AdminException>().having((e) => e.statusCode, 'statusCode', 401),
        ),
      );
    });

    test('throws AdminException with parsed error on other errors', () async {
      final middleware = _CapturingAuthMiddleware(
        statusCode: 500,
        responseBody: {'error': 'Internal server error'},
      );
      final service = AdminService(authMiddleware: middleware);

      await expectLater(
        service.getSubmissions(),
        throwsA(
          isA<AdminException>()
              .having((e) => e.message, 'message', 'Internal server error')
              .having((e) => e.statusCode, 'statusCode', 500),
        ),
      );
    });
  });

  group('AdminService.getUsers', () {
    test('returns list of users on 200', () async {
      final middleware = _CapturingAuthMiddleware(
        responseBody: [
          _testUser,
          {..._testUser, 'id': '2', 'username': 'user2'},
        ],
      );
      final service = AdminService(authMiddleware: middleware);

      final users = await service.getUsers();

      expect(users, hasLength(2));
      expect(users[0].username, 'testuser');
      expect(users[1].username, 'user2');
      expect(middleware.requests, hasLength(1));
      expect(middleware.requests.single.method, 'GET');
      expect(middleware.requests.single.url, endsWith('/admin/users'));
    });

    test('throws AdminException on 401', () async {
      final middleware = _CapturingAuthMiddleware(
        statusCode: 401,
        responseBody: {'error': 'Unauthorized'},
      );
      final service = AdminService(authMiddleware: middleware);

      await expectLater(
        service.getUsers(),
        throwsA(
          isA<AdminException>().having((e) => e.statusCode, 'statusCode', 401),
        ),
      );
    });
  });

  group('AdminService.getUser', () {
    test('returns user on 200', () async {
      final middleware = _CapturingAuthMiddleware(responseBody: _testUser);
      final service = AdminService(authMiddleware: middleware);

      final user = await service.getUser(
        'a1b2c3d4-e5f6-7890-abcd-ef1234567890',
      );

      expect(user.username, 'testuser');
      expect(user.email, 'test@example.com');
      expect(middleware.requests, hasLength(1));
      expect(middleware.requests.single.method, 'GET');
      expect(
        middleware.requests.single.url,
        endsWith('/admin/users/a1b2c3d4-e5f6-7890-abcd-ef1234567890'),
      );
    });

    test('throws AdminException on 401', () async {
      final middleware = _CapturingAuthMiddleware(
        statusCode: 401,
        responseBody: {'error': 'Unauthorized'},
      );
      final service = AdminService(authMiddleware: middleware);

      await expectLater(
        service.getUser('some-id'),
        throwsA(
          isA<AdminException>().having((e) => e.statusCode, 'statusCode', 401),
        ),
      );
    });

    test('throws AdminException on 404', () async {
      final middleware = _CapturingAuthMiddleware(
        statusCode: 404,
        responseBody: {'error': 'Not found'},
      );
      final service = AdminService(authMiddleware: middleware);

      await expectLater(
        service.getUser('nonexistent'),
        throwsA(
          isA<AdminException>()
              .having((e) => e.statusCode, 'statusCode', 404)
              .having((e) => e.message, 'message', 'Not found'),
        ),
      );
    });
  });

  group('AdminService.activateUser', () {
    test('posts to activate endpoint and returns updated user', () async {
      final activatedUser = {..._testUser, 'is_active': true};
      final middleware = _CapturingAuthMiddleware(responseBody: activatedUser);
      final service = AdminService(authMiddleware: middleware);

      final user = await service.activateUser('user-id');

      expect(user.isActive, isTrue);
      expect(middleware.requests, hasLength(1));
      expect(middleware.requests.single.method, 'POST');
      expect(
        middleware.requests.single.url,
        endsWith('/admin/users/user-id/active'),
      );
    });

    test('throws AdminException on 404', () async {
      final middleware = _CapturingAuthMiddleware(
        statusCode: 404,
        responseBody: {'error': 'Not found'},
      );
      final service = AdminService(authMiddleware: middleware);

      await expectLater(
        service.activateUser('nonexistent'),
        throwsA(
          isA<AdminException>().having((e) => e.statusCode, 'statusCode', 404),
        ),
      );
    });
  });

  group('AdminService.deactivateUser', () {
    test('posts to deactivate endpoint and returns updated user', () async {
      final deactivatedUser = {..._testUser, 'is_active': false};
      final middleware = _CapturingAuthMiddleware(
        responseBody: deactivatedUser,
      );
      final service = AdminService(authMiddleware: middleware);

      final user = await service.deactivateUser('user-id');

      expect(user.isActive, isFalse);
      expect(middleware.requests, hasLength(1));
      expect(middleware.requests.single.method, 'POST');
      expect(
        middleware.requests.single.url,
        endsWith('/admin/users/user-id/inactive'),
      );
    });

    test('throws AdminException on 404', () async {
      final middleware = _CapturingAuthMiddleware(
        statusCode: 404,
        responseBody: {'error': 'Not found'},
      );
      final service = AdminService(authMiddleware: middleware);

      await expectLater(
        service.deactivateUser('nonexistent'),
        throwsA(
          isA<AdminException>().having((e) => e.statusCode, 'statusCode', 404),
        ),
      );
    });
  });

  group('AdminService.deleteQuestion', () {
    test('posts to delete endpoint on success (200)', () async {
      final middleware = _CapturingAuthMiddleware(statusCode: 200);
      final service = AdminService(authMiddleware: middleware);

      await service.deleteQuestion(42);

      expect(middleware.requests, hasLength(1));
      expect(middleware.requests.single.method, 'POST');
      expect(
        middleware.requests.single.url,
        endsWith('/admin/questions/42/delete'),
      );
    });

    test('posts to delete endpoint on success (204)', () async {
      final middleware = _CapturingAuthMiddleware(statusCode: 204);
      final service = AdminService(authMiddleware: middleware);

      await service.deleteQuestion(42);

      expect(middleware.requests, hasLength(1));
    });

    test('throws AdminException on 401', () async {
      final middleware = _CapturingAuthMiddleware(
        statusCode: 401,
        responseBody: {'error': 'Unauthorized'},
      );
      final service = AdminService(authMiddleware: middleware);

      await expectLater(
        service.deleteQuestion(1),
        throwsA(
          isA<AdminException>().having((e) => e.statusCode, 'statusCode', 401),
        ),
      );
    });

    test('throws AdminException on 404', () async {
      final middleware = _CapturingAuthMiddleware(
        statusCode: 404,
        responseBody: {'error': 'Not found'},
      );
      final service = AdminService(authMiddleware: middleware);

      await expectLater(
        service.deleteQuestion(1),
        throwsA(
          isA<AdminException>().having((e) => e.statusCode, 'statusCode', 404),
        ),
      );
    });
  });

  group('AdminService.changeQuestionText', () {
    test('patches to change endpoint with new text on success', () async {
      final middleware = _CapturingAuthMiddleware(statusCode: 200);
      final service = AdminService(authMiddleware: middleware);

      await service.changeQuestionText(42, 'New question text?');

      expect(middleware.requests, hasLength(1));
      expect(middleware.requests.single.method, 'PATCH');
      expect(
        middleware.requests.single.url,
        endsWith('/admin/questions/42/change'),
      );
      expect(middleware.requests.single.jsonBody, {
        'text': 'New question text?',
      });
    });

    test('throws AdminException on 400 with error message', () async {
      final middleware = _CapturingAuthMiddleware(
        statusCode: 400,
        responseBody: {'error': 'Question text too short'},
      );
      final service = AdminService(authMiddleware: middleware);

      await expectLater(
        service.changeQuestionText(1, 'Short'),
        throwsA(
          isA<AdminException>()
              .having((e) => e.message, 'message', 'Question text too short')
              .having((e) => e.statusCode, 'statusCode', 400),
        ),
      );
    });

    test('throws AdminException on 401', () async {
      final middleware = _CapturingAuthMiddleware(
        statusCode: 401,
        responseBody: {'error': 'Unauthorized'},
      );
      final service = AdminService(authMiddleware: middleware);

      await expectLater(
        service.changeQuestionText(1, 'New text'),
        throwsA(
          isA<AdminException>().having((e) => e.statusCode, 'statusCode', 401),
        ),
      );
    });

    test('throws AdminException on 404', () async {
      final middleware = _CapturingAuthMiddleware(
        statusCode: 404,
        responseBody: {'error': 'Not found'},
      );
      final service = AdminService(authMiddleware: middleware);

      await expectLater(
        service.changeQuestionText(1, 'New text'),
        throwsA(
          isA<AdminException>().having((e) => e.statusCode, 'statusCode', 404),
        ),
      );
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
