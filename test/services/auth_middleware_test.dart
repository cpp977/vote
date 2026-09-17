import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vote/services/auth_middleware.dart';
import 'package:vote/services/auth_service.dart';
import 'package:vote/services/navigation_service.dart';
import 'package:vote/services/token_storage.dart';

/// A mock HTTP client that records requests and returns canned responses.
class _MockHttpClient extends http.BaseClient {
  _MockHttpClient();

  final List<_CapturedRequest> requests = [];

  // Response configuration
  int statusCode = 200;
  Map<String, String>? responseHeaders;
  String responseBodyString = '{}';

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
    responseHeaders = null;
    responseBodyString = '{}';
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

/// Testable version of AuthMiddleware that uses a mock HTTP client.
/// This extends AuthMiddleware and overrides httpClient with a mock.
class _TestableAuthMiddleware extends AuthMiddleware {
  _TestableAuthMiddleware({
    required this.mockClient,
    AuthService? authService,
    TokenStorage? tokenStorage,
  }) : super(authService: authService, tokenStorage: tokenStorage);

  final _MockHttpClient mockClient;

  @override
  http.Client get httpClient => mockClient;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AuthMiddleware', () {
    late _MockHttpClient mockClient;
    late _TestableAuthMiddleware middleware;
    late TokenStorage tokenStorage;
    late AuthService authService;

    setUp(() {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      mockClient = _MockHttpClient();
      tokenStorage = TokenStorage();
      authService = AuthService();
      middleware = _TestableAuthMiddleware(
        mockClient: mockClient,
        authService: authService,
        tokenStorage: tokenStorage,
      );
    });

    group('successful requests', () {
      test('GET request adds Authorization header when token exists', () async {
        await tokenStorage.setAccessToken('test-access-token');
        mockClient.statusCode = 200;
        mockClient.responseBodyString = '{"data": "test"}';

        final response = await middleware.get('https://api.example.com/test');

        expect(response.statusCode, 200);
        expect(mockClient.requests, hasLength(1));
        expect(
          mockClient.requests.single.headers['Authorization'],
          'Bearer test-access-token',
        );
      });

      test('GET request works without token', () async {
        mockClient.statusCode = 200;
        mockClient.responseBodyString = '{"data": "public"}';

        final response = await middleware.get('https://api.example.com/public');

        expect(response.statusCode, 200);
        expect(
          mockClient.requests.single.headers.containsKey('Authorization'),
          isFalse,
        );
      });

      test('POST request includes body and token', () async {
        await tokenStorage.setAccessToken('test-access-token');
        mockClient.statusCode = 201;
        mockClient.responseBodyString = '{"id": 1}';

        final response = await middleware.post(
          'https://api.example.com/items',
          body: '{"name": "test"}',
        );

        expect(response.statusCode, 201);
        expect(mockClient.requests.single.jsonBody['name'], 'test');
        expect(
          mockClient.requests.single.headers['Authorization'],
          'Bearer test-access-token',
        );
      });

      test('PUT request works correctly', () async {
        await tokenStorage.setAccessToken('test-access-token');
        mockClient.statusCode = 200;
        mockClient.responseBodyString = '{"updated": true}';

        final response = await middleware.put(
          'https://api.example.com/items/1',
          body: '{"name": "updated"}',
        );

        expect(response.statusCode, 200);
        expect(mockClient.requests.single.method, 'PUT');
      });

      test('PATCH request works correctly', () async {
        await tokenStorage.setAccessToken('test-access-token');
        mockClient.statusCode = 200;
        mockClient.responseBodyString = '{"patched": true}';

        final response = await middleware.patch(
          'https://api.example.com/items/1',
          body: '{"name": "patched"}',
        );

        expect(response.statusCode, 200);
        expect(mockClient.requests.single.method, 'PATCH');
      });

      test('DELETE request works correctly', () async {
        await tokenStorage.setAccessToken('test-access-token');
        mockClient.statusCode = 204;

        final response = await middleware.delete(
          'https://api.example.com/items/1',
        );

        expect(response.statusCode, 204);
        expect(mockClient.requests.single.method, 'DELETE');
      });

      test('includes custom headers', () async {
        await tokenStorage.setAccessToken('test-access-token');
        mockClient.statusCode = 200;

        await middleware.get(
          'https://api.example.com/test',
          headers: {'X-Custom-Header': 'custom-value'},
        );

        expect(
          mockClient.requests.single.headers['X-Custom-Header'],
          'custom-value',
        );
      });
    });

    group('423 account locked', () {
      test('clears tokens on 423 response', () async {
        await tokenStorage.setAccessToken('test-access-token');
        await tokenStorage.setRefreshToken('test-refresh-token');

        mockClient.statusCode = 423;
        mockClient.responseBodyString = '{"error": "Account locked"}';

        final response = await middleware.get('https://api.example.com/test');

        expect(response.statusCode, 423);
        expect(await tokenStorage.hasTokens(), isFalse);
      });
    });

    group('401 handling', () {
      test('returns 401 without retry when no refresh token', () async {
        await tokenStorage.setAccessToken('test-token');
        mockClient.statusCode = 401;
        mockClient.responseBodyString = '{"error": "Unauthorized"}';

        final response = await middleware.get('https://api.example.com/test');

        expect(response.statusCode, 401);
        // Should only make one request (no retry)
        expect(mockClient.requests, hasLength(1));
      });
    });

    group('error responses', () {
      test('returns error response without throwing on 500', () async {
        mockClient.statusCode = 500;
        mockClient.responseBodyString = '{"error": "Internal server error"}';

        final response = await middleware.get('https://api.example.com/test');

        expect(response.statusCode, 500);
        expect(response.body, '{"error": "Internal server error"}');
      });

      test('returns 403 without retry', () async {
        await tokenStorage.setAccessToken('test-token');
        mockClient.statusCode = 403;
        mockClient.responseBodyString = '{"error": "Forbidden"}';

        final response = await middleware.get('https://api.example.com/test');

        expect(response.statusCode, 403);
        expect(mockClient.requests, hasLength(1));
      });

      test('returns 404 without retry', () async {
        await tokenStorage.setAccessToken('test-token');
        mockClient.statusCode = 404;
        mockClient.responseBodyString = '{"error": "Not found"}';

        final response = await middleware.get('https://api.example.com/test');

        expect(response.statusCode, 404);
        expect(mockClient.requests, hasLength(1));
      });
    });
  });
}
