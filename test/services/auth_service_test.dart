import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:vote/models/auth_models.dart';
import 'package:vote/services/auth_service.dart';

/// A mock HTTP client that records requests and returns canned responses.
class _MockHttpClient extends http.BaseClient {
  _MockHttpClient();

  final List<_CapturedRequest> requests = [];

  // Response configuration
  int statusCode = 200;
  dynamic responseBody; // Can be Map, List, or String
  Map<String, String>? responseHeaders;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final bodyBytes = await request.finalize().fold<List<int>>(
      [],
      (prev, curr) => prev..addAll(curr),
    );
    final bodyString = utf8.decode(bodyBytes);
    requests.add(
      _CapturedRequest(
        request.method,
        request.url.toString(),
        bodyString,
        request.headers,
      ),
    );

    String responseBodyString;
    if (responseBody == null) {
      responseBodyString = '[]';
    } else if (responseBody is Map || responseBody is List) {
      responseBodyString = jsonEncode(responseBody);
    } else if (responseBody is String) {
      responseBodyString = responseBody;
    } else {
      responseBodyString = '';
    }

    final response = http.Response(
      responseBodyString,
      statusCode,
      headers: responseHeaders ?? {},
    );
    return http.StreamedResponse(
      Stream.fromIterable([response.bodyBytes]),
      response.statusCode,
      headers: response.headers,
    );
  }

  void reset() {
    requests.clear();
    statusCode = 200;
    responseBody = null;
    responseHeaders = null;
  }
}

class _CapturedRequest {
  final String method;
  final String url;
  final String body;
  final Map<String, String> headers;

  const _CapturedRequest(this.method, this.url, this.body, this.headers);

  Map<String, dynamic> get jsonBody => body.isEmpty
      ? <String, dynamic>{}
      : jsonDecode(body) as Map<String, dynamic>;
}

/// Testable version of AuthService that uses a mock HTTP client.
class _TestableAuthService extends AuthService {
  _TestableAuthService(this._mockClient) {
    httpClient = _mockClient;
  }

  final _MockHttpClient _mockClient;
}

// Test data constants
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

const _testAuthResponse = <String, dynamic>{
  'access_token': 'test-access-token',
  'refresh_token': 'test-refresh-token',
};

const _testCountry = <String, dynamic>{'code': 'US', 'name': 'United States'};

const _testRegion = <String, dynamic>{
  'code': 'CA',
  'name': 'California',
  'country_code': 'US',
};

const _testCategory = <String, dynamic>{
  'id': 1,
  'name': 'General',
  'language': 'en',
};

const _testForgotPasswordResponse = <String, dynamic>{
  'message': 'If the email exists, a reset link has been sent.',
};

void main() {
  group('AuthService', () {
    late _MockHttpClient mockClient;
    late _TestableAuthService authService;

    setUp(() {
      mockClient = _MockHttpClient();
      authService = _TestableAuthService(mockClient);
    });

    group('getCountries', () {
      test('returns list of countries on 200', () async {
        mockClient.responseBody = [
          _testCountry,
          {'code': 'DE', 'name': 'Germany'},
        ];
        mockClient.statusCode = 200;

        final countries = await authService.getCountries();

        expect(countries, hasLength(2));
        expect(countries[0].code, 'US');
        expect(countries[0].name, 'United States');
        expect(countries[1].code, 'DE');
        expect(mockClient.requests, hasLength(1));
        expect(mockClient.requests.single.method, 'GET');
        expect(mockClient.requests.single.url, endsWith('/countries'));
      });

      test('throws ApiException on non-200', () async {
        mockClient.statusCode = 500;
        mockClient.responseBody = {'error': 'Server error'};

        await expectLater(
          authService.getCountries(),
          throwsA(
            isA<ApiException>().having((e) => e.statusCode, 'statusCode', 500),
          ),
        );
      });

      test('handles empty response body', () async {
        mockClient.statusCode = 200;
        mockClient.responseBody = [];

        final countries = await authService.getCountries();
        expect(countries, isEmpty);
      });

      test('handles null response body gracefully', () async {
        mockClient.statusCode = 200;
        mockClient.responseBody = null;

        final countries = await authService.getCountries();
        expect(countries, isEmpty);
      });
    });

    group('getRegions', () {
      test('returns list of regions on 200', () async {
        mockClient.responseBody = [
          _testRegion,
          {'code': 'NY', 'name': 'New York', 'country_code': 'US'},
        ];
        mockClient.statusCode = 200;

        final regions = await authService.getRegions();

        expect(regions, hasLength(2));
        expect(regions[0].code, 'CA');
        expect(regions[0].name, 'California');
        expect(regions[0].countryCode, 'US');
        expect(mockClient.requests.single.url, endsWith('/regions'));
      });

      test('throws ApiException on non-200', () async {
        mockClient.statusCode = 404;
        mockClient.responseBody = {'error': 'Not found'};

        await expectLater(
          authService.getRegions(),
          throwsA(isA<ApiException>()),
        );
      });
    });

    group('register', () {
      test('returns User on 201', () async {
        mockClient.responseBody = _testUser;
        mockClient.statusCode = 201;

        final user = await authService.register(
          RegisterRequest(
            username: 'newuser',
            email: 'new@example.com',
            password: 'password123',
          ),
        );

        expect(user.username, 'testuser');
        expect(user.email, 'test@example.com');
        expect(mockClient.requests, hasLength(1));
        expect(mockClient.requests.single.method, 'POST');
        expect(mockClient.requests.single.url, endsWith('/register'));
        expect(mockClient.requests.single.jsonBody['username'], 'newuser');
        expect(mockClient.requests.single.jsonBody['email'], 'new@example.com');
        expect(mockClient.requests.single.jsonBody['password'], 'password123');
      });

      test('includes optional fields when provided', () async {
        mockClient.responseBody = _testUser;
        mockClient.statusCode = 201;

        await authService.register(
          RegisterRequest(
            username: 'fulluser',
            email: 'full@example.com',
            password: 'password123',
            birthYear: 1995,
            gender: 'm',
            nationality: 'DE',
          ),
        );

        final body = mockClient.requests.single.jsonBody;
        expect(body['birth_year'], 1995);
        expect(body['gender'], 'm');
        expect(body['nationality'], 'DE');
      });

      test('omits null optional fields', () async {
        mockClient.responseBody = _testUser;
        mockClient.statusCode = 201;

        await authService.register(
          RegisterRequest(
            username: 'minimal',
            email: 'minimal@example.com',
            password: 'password123',
          ),
        );

        final body = mockClient.requests.single.jsonBody;
        expect(body.containsKey('birth_year'), isFalse);
        expect(body.containsKey('gender'), isFalse);
        expect(body.containsKey('nationality'), isFalse);
      });

      test('throws ApiException on 409 conflict', () async {
        mockClient.statusCode = 409;
        mockClient.responseBody = {'error': 'Username already taken'};

        await expectLater(
          authService.register(
            RegisterRequest(
              username: 'existing',
              email: 'existing@example.com',
              password: 'password123',
            ),
          ),
          throwsA(
            isA<ApiException>().having((e) => e.statusCode, 'statusCode', 409),
          ),
        );
      });

      test('throws ApiException on 400 bad request', () async {
        mockClient.statusCode = 400;
        mockClient.responseBody = {'error': 'Invalid email format'};

        await expectLater(
          authService.register(
            RegisterRequest(
              username: 'test',
              email: 'invalid-email',
              password: 'password123',
            ),
          ),
          throwsA(isA<ApiException>()),
        );
      });
    });

    group('login', () {
      test('returns AuthResponse on 200', () async {
        mockClient.responseBody = _testAuthResponse;
        mockClient.statusCode = 200;

        final authResponse = await authService.login(
          LoginRequest(username: 'testuser', password: 'password123'),
        );

        expect(authResponse.accessToken, 'test-access-token');
        expect(authResponse.refreshToken, 'test-refresh-token');
        expect(mockClient.requests.single.url, endsWith('/login'));
        expect(mockClient.requests.single.jsonBody['username'], 'testuser');
        expect(mockClient.requests.single.jsonBody['password'], 'password123');
      });

      test('throws ApiException on 401 unauthorized', () async {
        mockClient.statusCode = 401;
        mockClient.responseBody = {'error': 'Invalid credentials'};

        await expectLater(
          authService.login(LoginRequest(username: 'test', password: 'wrong')),
          throwsA(
            isA<ApiException>().having((e) => e.statusCode, 'statusCode', 401),
          ),
        );
      });

      test('throws ApiException on 400 bad request', () async {
        mockClient.statusCode = 400;
        mockClient.responseBody = {'error': 'Missing username'};

        await expectLater(
          authService.login(LoginRequest(username: '', password: 'password')),
          throwsA(isA<ApiException>()),
        );
      });
    });

    group('logout', () {
      test('sends logout request with access token', () async {
        mockClient.statusCode = 204;

        await authService.logout(
          LogoutRequest(refreshToken: 'refresh-token'),
          'access-token',
        );

        expect(mockClient.requests, hasLength(1));
        expect(mockClient.requests.single.method, 'POST');
        expect(mockClient.requests.single.url, endsWith('/logout'));
        expect(
          mockClient.requests.single.jsonBody['refresh_token'],
          'refresh-token',
        );
      });

      test('throws ApiException on failure with error body', () async {
        mockClient.statusCode = 400;
        mockClient.responseBody = {'error': 'Invalid refresh token'};

        await expectLater(
          authService.logout(
            LogoutRequest(refreshToken: 'bad'),
            'access-token',
          ),
          throwsA(
            isA<ApiException>().having((e) => e.statusCode, 'statusCode', 400),
          ),
        );
      });

      test('throws ApiException on failure with empty body', () async {
        mockClient.statusCode = 500;
        mockClient.responseBody = '';

        await expectLater(
          authService.logout(
            LogoutRequest(refreshToken: 'token'),
            'access-token',
          ),
          throwsA(
            isA<ApiException>().having(
              (e) => e.message,
              'message',
              contains('Logout failed'),
            ),
          ),
        );
      });
    });

    group('refresh', () {
      test('returns new AuthResponse on 200', () async {
        mockClient.responseBody = _testAuthResponse;
        mockClient.statusCode = 200;

        final authResponse = await authService.refresh(
          RefreshRequest(refreshToken: 'old-refresh'),
        );

        expect(authResponse.accessToken, 'test-access-token');
        expect(authResponse.refreshToken, 'test-refresh-token');
        expect(mockClient.requests.single.url, endsWith('/refresh'));
        expect(
          mockClient.requests.single.jsonBody['refresh_token'],
          'old-refresh',
        );
      });

      test('throws ApiException on 401', () async {
        mockClient.statusCode = 401;
        mockClient.responseBody = {'error': 'Invalid refresh token'};

        await expectLater(
          authService.refresh(RefreshRequest(refreshToken: 'invalid')),
          throwsA(isA<ApiException>()),
        );
      });
    });

    group('getCurrentUser', () {
      test('returns User on 200', () async {
        mockClient.responseBody = _testUser;
        mockClient.statusCode = 200;

        final user = await authService.getCurrentUser('valid-access-token');

        expect(user.username, 'testuser');
        expect(user.email, 'test@example.com');
        expect(mockClient.requests.single.url, endsWith('/me'));
      });

      test('throws ApiException on 401', () async {
        mockClient.statusCode = 401;
        mockClient.responseBody = {'error': 'Unauthorized'};

        await expectLater(
          authService.getCurrentUser('expired-token'),
          throwsA(isA<ApiException>()),
        );
      });
    });

    group('updateCurrentUser', () {
      test('returns updated User on 200', () async {
        mockClient.responseBody = {
          ..._testUser,
          'email': 'updated@example.com',
          'gender': 'm',
        };
        mockClient.statusCode = 200;

        final user = await authService.updateCurrentUser(
          'access-token',
          UpdateUserRequest(email: 'updated@example.com', gender: 'm'),
        );

        expect(user.email, 'updated@example.com');
        expect(user.gender, 'm');
        expect(mockClient.requests.single.method, 'PATCH');
        expect(mockClient.requests.single.url, endsWith('/me'));
        expect(
          mockClient.requests.single.jsonBody['email'],
          'updated@example.com',
        );
        expect(mockClient.requests.single.jsonBody['gender'], 'm');
      });

      test('includes password when provided', () async {
        mockClient.responseBody = _testUser;
        mockClient.statusCode = 200;

        await authService.updateCurrentUser(
          'access-token',
          UpdateUserRequest(email: 'new@example.com', password: 'newpass123'),
        );

        expect(mockClient.requests.single.jsonBody['password'], 'newpass123');
      });

      test('omits null fields', () async {
        mockClient.responseBody = _testUser;
        mockClient.statusCode = 200;

        await authService.updateCurrentUser(
          'access-token',
          UpdateUserRequest(email: 'new@example.com'),
        );

        final body = mockClient.requests.single.jsonBody;
        expect(body.containsKey('gender'), isFalse);
        expect(body.containsKey('password'), isFalse);
        expect(body.containsKey('nationality'), isFalse);
        expect(body.containsKey('region'), isFalse);
      });

      test('throws ApiException on failure', () async {
        mockClient.statusCode = 400;
        mockClient.responseBody = {'error': 'Email already in use'};

        await expectLater(
          authService.updateCurrentUser(
            'access-token',
            UpdateUserRequest(email: 'taken@example.com'),
          ),
          throwsA(isA<ApiException>()),
        );
      });
    });

    group('forgotPassword', () {
      test('returns ForgotPasswordResponse on 200', () async {
        mockClient.responseBody = _testForgotPasswordResponse;
        mockClient.statusCode = 200;

        final response = await authService.forgotPassword(
          ForgotPasswordRequest(email: 'test@example.com'),
        );

        expect(
          response.message,
          'If the email exists, a reset link has been sent.',
        );
        expect(
          mockClient.requests.single.url,
          endsWith('/user/password/forgot'),
        );
        expect(
          mockClient.requests.single.jsonBody['email'],
          'test@example.com',
        );
      });

      test('throws ApiException on 400', () async {
        mockClient.statusCode = 400;
        mockClient.responseBody = {'error': 'Invalid email format'};

        await expectLater(
          authService.forgotPassword(ForgotPasswordRequest(email: 'invalid')),
          throwsA(isA<ApiException>()),
        );
      });
    });

    group('resetPassword', () {
      test('completes successfully on 200', () async {
        mockClient.statusCode = 200;

        await authService.resetPassword('valid-token', 'newpassword123');

        expect(mockClient.requests, hasLength(1));
        expect(
          mockClient.requests.single.url,
          endsWith('/user/password/reset'),
        );
        expect(mockClient.requests.single.jsonBody['token'], 'valid-token');
        expect(
          mockClient.requests.single.jsonBody['password'],
          'newpassword123',
        );
      });

      test('throws ApiException on failure', () async {
        mockClient.statusCode = 400;
        mockClient.responseBody = {'error': 'Invalid or expired token'};

        await expectLater(
          authService.resetPassword('invalid-token', 'newpassword123'),
          throwsA(isA<ApiException>()),
        );
      });
    });

    group('getCategories', () {
      test('returns list of categories on 200', () async {
        mockClient.responseBody = [
          _testCategory,
          {'id': 2, 'name': 'Health', 'language': 'en'},
        ];
        mockClient.statusCode = 200;

        final categories = await authService.getCategories('en');

        expect(categories, hasLength(2));
        expect(categories[0].id, 1);
        expect(categories[0].name, 'General');
        expect(mockClient.requests.single.url, endsWith('/categories/lang/en'));
      });

      test('includes Authorization header when accessToken provided', () async {
        mockClient.responseBody = [_testCategory];
        mockClient.statusCode = 200;

        await authService.getCategories('de', accessToken: 'auth-token');

        expect(mockClient.requests.single.url, endsWith('/categories/lang/de'));
        expect(
          mockClient.requests.single.headers['Authorization'],
          'Bearer auth-token',
        );
      });

      test('throws ApiException on failure', () async {
        mockClient.statusCode = 404;
        mockClient.responseBody = {'error': 'Language not supported'};

        await expectLater(
          authService.getCategories('xx'),
          throwsA(isA<ApiException>()),
        );
      });
    });

    group('deleteAccount', () {
      test('sends DELETE request with access token on success', () async {
        mockClient.statusCode = 204;

        await authService.deleteAccount('access-token');

        expect(mockClient.requests, hasLength(1));
        expect(mockClient.requests.single.method, 'DELETE');
        expect(mockClient.requests.single.url, endsWith('/users/me/delete'));
        expect(
          mockClient.requests.single.headers['Authorization'],
          'Bearer access-token',
        );
      });

      test('throws ApiException on failure with error body', () async {
        mockClient.statusCode = 400;
        mockClient.responseBody = {'error': 'Cannot delete admin account'};

        await expectLater(
          authService.deleteAccount('access-token'),
          throwsA(
            isA<ApiException>().having((e) => e.statusCode, 'statusCode', 400),
          ),
        );
      });

      test('throws ApiException on failure with empty body', () async {
        mockClient.statusCode = 500;
        mockClient.responseBody = '';

        await expectLater(
          authService.deleteAccount('access-token'),
          throwsA(
            isA<ApiException>().having(
              (e) => e.message,
              'message',
              contains('Delete failed'),
            ),
          ),
        );
      });
    });

    group('_parseError (via public methods)', () {
      test(
        'returns ApiException with requestFailed code for empty body',
        () async {
          mockClient.statusCode = 503;
          mockClient.responseBody = '';

          await expectLater(
            authService.getCountries(),
            throwsA(
              isA<ApiException>()
                  .having((e) => e.code, 'code', 'requestFailed')
                  .having(
                    (e) => e.message,
                    'message',
                    contains('Request failed'),
                  ),
            ),
          );
        },
      );

      test('preserves server error message when JSON parsing fails', () async {
        mockClient.statusCode = 500;
        mockClient.responseBody = 'Internal Server Error';

        await expectLater(
          authService.getCountries(),
          throwsA(
            isA<ApiException>().having(
              (e) => e.message,
              'message',
              'Internal Server Error',
            ),
          ),
        );
      });
    });
  });
}
