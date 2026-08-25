import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../config/api_config.dart';
import '../models/answer_stats.dart';
import '../models/stats_dimensions.dart';
import 'auth_middleware.dart';

/// Thrown by [QuestionStatsService.fetch] when a request cannot be served at
/// the transport/auth level (e.g. HTTP 401). Segment-level outcomes such as
/// `insufficient_data` are returned as [SegmentResult] instead.
class StatsException implements Exception {
  final int? statusCode;

  const StatsException(this.statusCode);

  @override
  String toString() => 'StatsException($statusCode)';
}

/// Fetches per-segment voting statistics for a question.
///
/// Requests go through [AuthMiddleware] so expired access tokens are refreshed
/// transparently and retried.
class QuestionStatsService {
  final AuthMiddleware _authMiddleware;

  QuestionStatsService({AuthMiddleware? authMiddleware})
    : _authMiddleware = authMiddleware ?? AuthMiddleware();

  /// Loads the statistics for [questionId] resolved to the segment selected by
  /// [query]. An overall query ([StatsQuery.isOverall]) sends no parameters;
  /// otherwise each active filter becomes one query parameter.
  ///
  /// Returns the parsed [SegmentResult]; throws [StatsException] on 401 so
  /// callers can route to login.
  Future<SegmentResult> fetch(int questionId, StatsQuery query) async {
    final uri = Uri.parse(
      '${ApiConfig.baseUrl}/questions/$questionId/stats',
    ).replace(queryParameters: query.isOverall ? null : query.filters);
    final response = await _authMiddleware.get(uri.toString());

    if (response.statusCode == 200) {
      return _parseEnvelope(response.body);
    } else if (response.statusCode == 401) {
      throw const StatsException(401);
    } else if (response.statusCode == 404) {
      return const SegmentResult.error(SegmentErrorKind.notAvailable);
    }
    return const SegmentResult.error(SegmentErrorKind.loadFailed);
  }

  /// Parses the `{status, answers}` envelope; `insufficient_data` is a valid,
  /// non-error outcome for segments below the backend's anonymity threshold.
  SegmentResult _parseEnvelope(String body) {
    try {
      final Map<String, dynamic> envelope =
          jsonDecode(body) as Map<String, dynamic>;
      if ((envelope['status'] as String? ?? '') == 'insufficient_data') {
        return const SegmentResult.insufficient();
      }
      final List<dynamic> data = (envelope['answers'] as List?) ?? <dynamic>[];
      return SegmentResult.ok(
        data
            .map((e) => AnswerStats.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
    } catch (_) {
      return const SegmentResult.error(
        SegmentErrorKind.loadFailed,
        errorDetail: 'Malformed statistics response',
      );
    }
  }

  /// Loads the statistics tag contract from `GET /stats/meta` so filter UIs
  /// reflect the server's actual configuration (bucket width, available
  /// nationalities, newly added tags) instead of a hardcoded copy.
  ///
  /// Throws [StatsException] on non-200 responses; malformed bodies surface
  /// as [FormatException].
  Future<StatsMeta> fetchMeta() async {
    final response = await _authMiddleware.get(
      '${ApiConfig.baseUrl}/stats/meta',
    );
    if (response.statusCode != 200) {
      throw StatsException(response.statusCode);
    }
    final Map<String, dynamic> envelope =
        jsonDecode(response.body) as Map<String, dynamic>;
    final dimensions = <String, List<String>>{};
    for (final entry in (envelope['dimensions'] as List? ?? const [])) {
      final map = entry as Map<String, dynamic>;
      dimensions[map['key'] as String] = ((map['values'] as List?) ?? const [])
          .map((v) => v.toString())
          .toList();
    }
    return StatsMeta(
      ageBucketSize: (envelope['age_bucket_size'] as num?)?.toInt() ?? 10,
      minAnswers: (envelope['min_answers'] as num?)?.toInt() ?? 5,
      dimensions: dimensions,
    );
  }
}

/// Load state of a single segment: either in-flight or holding a result.
class SegmentLoadState {
  final bool isLoading;
  final SegmentResult? result;

  const SegmentLoadState.loading() : isLoading = true, result = null;

  const SegmentLoadState.done(this.result)
    : isLoading = false,
      assert(result != null);
}

/// Owns the statistics state shown for one question: the currently selected
/// segment ([activeQuery]) plus an in-memory cache of already-loaded segments
/// keyed by [StatsQuery.cacheKey].
///
/// Segments load lazily — only the query that is actually displayed is fetched,
/// and repeat selections hit the cache. After a new vote is recorded call
/// [refresh] to drop all cached segments and reload the visible one.
class QuestionStatsController extends ChangeNotifier {
  final int _questionId;
  final QuestionStatsService _service;

  /// Called when the backend rejects a request as unauthorized, so the host
  /// page can route the user back to login.
  final void Function()? _onUnauthorized;

  StatsQuery _activeQuery = StatsQuery.overall();
  final Map<String, SegmentLoadState> _states = {};
  final Map<String, Future<void>> _inflight = {};

  /// UI-ready dimensions once metadata has loaded; null until then.
  List<StatsDimension>? _dimensions;
  Future<void>? _metaLoad;

  QuestionStatsController({
    required this._questionId,
    QuestionStatsService? service,
    AuthMiddleware? authMiddleware,
    void Function()? onUnauthorized,
  }) : _service =
           service ?? QuestionStatsService(authMiddleware: authMiddleware),
       // ignore: prefer_initializing_formals
       _onUnauthorized = onUnauthorized;

  /// The segment whose statistics are currently displayed.
  StatsQuery get activeQuery => _activeQuery;

  /// Dimensions for the filter UI: derived from `/stats/meta` once loaded,
  /// falling back to the built-in registry before that (or on failure).
  List<StatsDimension> get dimensions => _dimensions ?? statsDimensions;

  /// Loads the tag contract from `/stats/meta` exactly once. Failures are
  /// non-fatal — the built-in fallback dimensions stay in effect — so this
  /// is safe to fire-and-forget at page entry.
  Future<void> loadMeta() {
    return _metaLoad ??= () async {
      try {
        final meta = await _service.fetchMeta();
        _dimensions = dimensionsFromMeta(meta);
        notifyListeners();
      } catch (_) {
        // Optional enhancement only; keep fallback dimensions.
      }
    }();
  }

  /// Load state for [query], loading if it was never requested.
  SegmentLoadState stateFor(StatsQuery query) =>
      _states[query.cacheKey] ?? const SegmentLoadState.loading();

  /// Convenience accessor for the displayed segment's state.
  SegmentLoadState get activeState => stateFor(_activeQuery);

  /// Displays [query], fetching its statistics if not cached yet.
  void select(StatsQuery query) {
    _activeQuery = query;
    notifyListeners();
    unawaited(ensureLoaded(query));
  }

  /// Fetches [query] unless cached or already in flight. In-flight requests
  /// are deduplicated so concurrent calls share one network round-trip.
  Future<void> ensureLoaded(StatsQuery query) async {
    final key = query.cacheKey;
    final existing = _states[key];
    if (existing != null && !existing.isLoading) return;
    final inflight = _inflight[key];
    if (inflight != null) return inflight;

    _states[key] = const SegmentLoadState.loading();
    notifyListeners();

    final future = _load(query);
    _inflight[key] = future;
    try {
      await future;
    } finally {
      _inflight.remove(key);
    }
  }

  /// Drops all cached segments and reloads the active one.
  Future<void> refresh() async {
    _states.clear();
    notifyListeners();
    await ensureLoaded(_activeQuery);
  }

  Future<void> _load(StatsQuery query) async {
    try {
      final result = await _service.fetch(_questionId, query);
      // Ignore stale completions if refresh() cleared the cache meanwhile.
      if (_states[query.cacheKey]?.isLoading ?? false) {
        _states[query.cacheKey] = SegmentLoadState.done(result);
      }
    } on StatsException catch (_) {
      _onUnauthorized?.call();
      _states[query.cacheKey] = SegmentLoadState.done(
        const SegmentResult.error(SegmentErrorKind.loadFailed),
      );
    } catch (e) {
      if (_states[query.cacheKey]?.isLoading ?? false) {
        _states[query.cacheKey] = SegmentLoadState.done(
          SegmentResult.error(
            SegmentErrorKind.loadFailed,
            errorDetail: e.toString(),
          ),
        );
      }
    } finally {
      notifyListeners();
    }
  }
}
