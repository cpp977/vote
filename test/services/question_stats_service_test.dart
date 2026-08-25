import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:vote/models/answer_stats.dart';
import 'package:vote/services/auth_middleware.dart';
import 'package:vote/services/question_stats_service.dart';

/// [AuthMiddleware] double that records GET URLs and answers with a canned
/// response, so the service/controller can be tested without real HTTP.
class _CapturingAuthMiddleware extends AuthMiddleware {
  _CapturingAuthMiddleware({this.statusCode = 200, this.responseBody});

  final List<Uri> requestedUris = [];
  int statusCode;
  Object? responseBody;

  @override
  Future<http.Response> get(String url, {Map<String, String>? headers}) async {
    requestedUris.add(Uri.parse(url));
    return http.Response(jsonEncode(responseBody), statusCode);
  }

  int get requestCount => requestedUris.length;
}

Map<String, dynamic> _okEnvelope([
  List<Map<String, dynamic>> answers = const [
    {'answer_id': 1, 'answer_text': 'Yes', 'count': 7, 'percent': 70.0},
    {'answer_id': 2, 'answer_text': 'No', 'count': 3, 'percent': 30.0},
  ],
]) => {'status': 'ok', 'answers': answers};

void main() {
  group('QuestionStatsService.fetch', () {
    test('overall query requests the endpoint without parameters', () async {
      final middleware = _CapturingAuthMiddleware(responseBody: _okEnvelope());
      final service = QuestionStatsService(authMiddleware: middleware);

      await service.fetch(42, StatsQuery.overall());

      expect(middleware.requestCount, 1);
      expect(middleware.requestedUris.single.path, '/questions/42/stats');
      expect(middleware.requestedUris.single.queryParameters, isEmpty);
    });

    test('filters become one query parameter per dimension', () async {
      final middleware = _CapturingAuthMiddleware(responseBody: _okEnvelope());
      final service = QuestionStatsService(authMiddleware: middleware);

      final query = StatsQuery()
          .withFilter('gender', 'm')
          .withFilter('age', '18-29')
          .withFilter('nationality', 'de');
      await service.fetch(42, query);

      expect(middleware.requestedUris.single.queryParameters, {
        'gender': 'm',
        'age': '18-29',
        'nationality': 'de',
      });
    });

    test('parses a successful envelope into answer statistics', () async {
      final middleware = _CapturingAuthMiddleware(responseBody: _okEnvelope());
      final service = QuestionStatsService(authMiddleware: middleware);

      final result = await service.fetch(42, StatsQuery.overall());

      expect(result.hasError, isFalse);
      expect(result.insufficientData, isFalse);
      expect(result.answers, hasLength(2));
      expect(result.answers.first.answerId, 1);
      expect(result.answers.first.answerText, 'Yes');
      expect(result.answers.first.count, 7);
      expect(result.answers.first.percent, 70.0);
    });

    test('maps an insufficient_data envelope to a neutral result', () async {
      final middleware = _CapturingAuthMiddleware(
        responseBody: {'status': 'insufficient_data'},
      );
      final service = QuestionStatsService(authMiddleware: middleware);

      final result = await service.fetch(42, StatsQuery.overall());

      expect(result.insufficientData, isTrue);
      expect(result.answers, isEmpty);
      expect(result.hasError, isFalse);
    });

    test('treats a missing answers list as empty success', () async {
      final middleware = _CapturingAuthMiddleware(
        responseBody: {'status': 'ok'},
      );
      final service = QuestionStatsService(authMiddleware: middleware);

      final result = await service.fetch(42, StatsQuery.overall());

      expect(result.hasError, isFalse);
      expect(result.answers, isEmpty);
    });

    test('maps 404 to notAvailable', () async {
      final middleware = _CapturingAuthMiddleware(statusCode: 404);
      final service = QuestionStatsService(authMiddleware: middleware);

      final result = await service.fetch(42, StatsQuery.overall());

      expect(result.errorKind, SegmentErrorKind.notAvailable);
    });

    test('maps other error statuses to loadFailed', () async {
      final middleware = _CapturingAuthMiddleware(statusCode: 500);
      final service = QuestionStatsService(authMiddleware: middleware);

      final result = await service.fetch(42, StatsQuery.overall());

      expect(result.errorKind, SegmentErrorKind.loadFailed);
    });

    test('throws on unauthorized so callers can route to login', () async {
      final middleware = _CapturingAuthMiddleware(statusCode: 401);
      final service = QuestionStatsService(authMiddleware: middleware);

      await expectLater(
        service.fetch(42, StatsQuery.overall()),
        throwsA(isA<StatsException>()),
      );
    });
  });

  group('QuestionStatsController', () {
    test('select loads the active segment and exposes its state', () async {
      final middleware = _CapturingAuthMiddleware(responseBody: _okEnvelope());
      final controller = QuestionStatsController(
        questionId: 1,
        authMiddleware: middleware,
      );

      controller.select(StatsQuery.overall());
      // Loading starts immediately; wait for completion.
      await Future<void>.delayed(Duration.zero);

      expect(controller.activeState.isLoading, isFalse);
      expect(controller.activeState.result!.answers, hasLength(2));
      expect(middleware.requestCount, 1);
    });

    test('re-selecting a loaded segment hits the cache', () async {
      final middleware = _CapturingAuthMiddleware(responseBody: _okEnvelope());
      final controller = QuestionStatsController(
        questionId: 1,
        authMiddleware: middleware,
      );
      final overall = StatsQuery.overall();
      final male = StatsQuery().withFilter('gender', 'm');

      controller.select(overall);
      await Future<void>.delayed(Duration.zero);
      controller.select(male);
      await Future<void>.delayed(Duration.zero);
      controller.select(overall);
      await Future<void>.delayed(Duration.zero);

      expect(controller.activeQuery, overall);
      expect(middleware.requestCount, 2); // overall + gender=m only
    });

    test('refresh drops cached segments and reloads the active one', () async {
      final middleware = _CapturingAuthMiddleware(responseBody: _okEnvelope());
      final controller = QuestionStatsController(
        questionId: 1,
        authMiddleware: middleware,
      );
      final overall = StatsQuery.overall();

      controller.select(overall);
      await Future<void>.delayed(Duration.zero);
      expect(middleware.requestCount, 1);

      await controller.refresh();
      expect(middleware.requestCount, 2);
      expect(controller.activeState.result!.answers, hasLength(2));
    });

    test('concurrent ensureLoaded calls share one request', () async {
      final middleware = _CapturingAuthMiddleware(responseBody: _okEnvelope());
      final controller = QuestionStatsController(
        questionId: 1,
        authMiddleware: middleware,
      );

      final query = StatsQuery().withFilter('age', '60+');
      await Future.wait([
        controller.ensureLoaded(query),
        controller.ensureLoaded(query),
        controller.ensureLoaded(query),
      ]);

      expect(controller.stateFor(query).result!.answers, hasLength(2));
      expect(middleware.requestCount, 1);
    });

    test('invokes onUnauthorized and records an error state on 401', () async {
      var unauthorizedCalls = 0;
      final middleware = _CapturingAuthMiddleware(statusCode: 401);
      final controller = QuestionStatsController(
        questionId: 1,
        authMiddleware: middleware,
        onUnauthorized: () => unauthorizedCalls++,
      );

      controller.select(StatsQuery.overall());
      await Future<void>.delayed(Duration.zero);

      expect(unauthorizedCalls, 1);
      expect(controller.activeState.isLoading, isFalse);
      expect(
        controller.activeState.result!.errorKind,
        SegmentErrorKind.loadFailed,
      );
    });

    test('notifies listeners while loading and after each result', () async {
      final middleware = _CapturingAuthMiddleware(responseBody: _okEnvelope());
      final controller = QuestionStatsController(
        questionId: 1,
        authMiddleware: middleware,
      );
      var notifications = 0;
      controller.addListener(() => notifications++);

      controller.select(StatsQuery.overall());
      await Future<void>.delayed(Duration.zero);

      // At minimum: select + loading + done.
      expect(notifications, greaterThanOrEqualTo(3));
    });
  });

  group('QuestionStatsService.fetchMeta', () {
    const metaEnvelope = {
      'age_bucket_size': 10,
      'min_answers': 5,
      'dimensions': [
        {
          'key': 'gender',
          'values': ['m', 'w', 'd'],
        },
        {
          'key': 'age_bucket',
          'values': ['0-9', '10-19'],
        },
        {
          'key': 'nationality',
          'values': ['AT', 'DE'],
        },
      ],
    };

    test('requests /stats/meta and parses the document', () async {
      final middleware = _CapturingAuthMiddleware(responseBody: metaEnvelope);
      final service = QuestionStatsService(authMiddleware: middleware);

      final meta = await service.fetchMeta();

      expect(middleware.requestedUris.single.path, '/stats/meta');
      expect(meta.ageBucketSize, 10);
      expect(meta.minAnswers, 5);
      expect(meta.dimensions['gender'], ['m', 'w', 'd']);
      expect(meta.dimensions['age_bucket'], ['0-9', '10-19']);
      expect(meta.dimensions['nationality'], ['AT', 'DE']);
    });

    test('throws StatsException on non-200 responses', () async {
      final middleware = _CapturingAuthMiddleware(statusCode: 500);
      final service = QuestionStatsService(authMiddleware: middleware);

      await expectLater(service.fetchMeta(), throwsA(isA<StatsException>()));
    });
  });

  group('QuestionStatsController.loadMeta', () {
    test('builds UI dimensions from fetched metadata', () async {
      final middleware = _CapturingAuthMiddleware(
        responseBody: {
          'age_bucket_size': 10,
          'min_answers': 5,
          'dimensions': [
            {
              'key': 'gender',
              'values': ['m', 'w', 'd'],
            },
          ],
        },
      );
      final controller = QuestionStatsController(
        questionId: 1,
        authMiddleware: middleware,
      );

      await controller.loadMeta();

      expect(controller.dimensions, hasLength(1));
      expect(controller.dimensions.single.key, 'gender');
      expect(controller.dimensions.single.values.map((v) => v.value), [
        'm',
        'w',
        'd',
      ]);
    });

    test('keeps fallback dimensions when the endpoint fails', () async {
      final middleware = _CapturingAuthMiddleware(statusCode: 404);
      final controller = QuestionStatsController(
        questionId: 1,
        authMiddleware: middleware,
      );
      final fallback = controller.dimensions;

      await controller.loadMeta();

      expect(controller.dimensions, same(fallback));
    });
  });
}
