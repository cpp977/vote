/// Statistics for a single answer option.
class AnswerStats {
  final int answerId;
  final String answerText;
  final int count;
  final double percent;

  AnswerStats({
    required this.answerId,
    required this.answerText,
    required this.count,
    required this.percent,
  });

  factory AnswerStats.fromJson(Map<String, dynamic> json) {
    return AnswerStats(
      answerId: json['answer_id'] as int,
      answerText: json['answer_text'] as String,
      count: json['count'] as int,
      percent: (json['percent'] as num).toDouble(),
    );
  }
}

/// Selects which voter segment statistics are resolved for.
///
/// An empty query means "everyone". Each entry maps a dimension key (the query
/// parameter name understood by the backend, e.g. `gender`) to exactly one of
/// that dimension's wire values (e.g. `m`). Because keys are unique, a query
/// holds at most one value per dimension; combinations across dimensions are
/// formed simply by adding several entries (e.g. gender=m + age=30-39).
///
/// Instances are immutable; [withFilter] and [withoutFilter] return copies.
class StatsQuery {
  final Map<String, String> _filters;

  StatsQuery({Map<String, String> filters = const {}})
    : _filters = Map.unmodifiable(filters);

  /// Query selecting every respondent without further filtering.
  StatsQuery.overall() : this();

  /// True when the query selects everyone (no dimension filters active).
  bool get isOverall => _filters.isEmpty;

  /// Active dimension filters; keyed by dimension key.
  Map<String, String> get filters => _filters;

  /// Value currently selected for [key], or null when the dimension is unset.
  String? valueOf(String key) => _filters[key];

  /// Returns a copy with [key] resolved to [value], replacing any prior value.
  StatsQuery withFilter(String key, String value) =>
      StatsQuery(filters: <String, String>{..._filters, key: value});

  /// Returns a copy without a filter on [key]; identical when none was set.
  StatsQuery withoutFilter(String key) {
    if (!_filters.containsKey(key)) return this;
    return StatsQuery(filters: <String, String>{..._filters}..remove(key));
  }

  /// Stable identity used for caching and equality; dimension order-insensitive.
  String get cacheKey {
    final keys = _filters.keys.toList()..sort();
    return keys.map((key) => '$key=${_filters[key]}').join('&');
  }

  @override
  bool operator ==(Object other) =>
      other is StatsQuery && other.cacheKey == cacheKey;

  @override
  int get hashCode => cacheKey.hashCode;
}

/// Why a requested segment's statistics are unavailable.
enum SegmentErrorKind {
  /// The backend reported the question (or endpoint) as unknown (HTTP 404).
  notAvailable,

  /// Any other failure (server error, network problem, malformed response).
  loadFailed,
}

/// Outcome of fetching statistics for one segment.
class SegmentResult {
  /// Per-answer statistics; only populated on success.
  final List<AnswerStats> answers;

  /// True when the backend withheld data because the segment is too small
  /// (`insufficient_data`).
  final bool insufficientData;

  final SegmentErrorKind? errorKind;

  /// Raw detail (e.g. an exception message) usable for diagnostics display.
  final String? errorDetail;

  const SegmentResult.ok(this.answers)
    : insufficientData = false,
      errorKind = null,
      errorDetail = null;

  const SegmentResult.insufficient()
    : answers = const [],
      insufficientData = true,
      errorKind = null,
      errorDetail = null;

  const SegmentResult.error(this.errorKind, {this.errorDetail})
    : answers = const [],
      insufficientData = false;

  bool get hasError => errorKind != null;
}

/// Metadata describing the statistics tag contract, served by
/// `GET /stats/meta`.
class StatsMeta {
  /// Width of one age bucket in years as configured server-side.
  final int ageBucketSize;

  /// Privacy threshold: segments with fewer matching answers are withheld.
  final int minAnswers;

  /// Allowed wire values per dimension key, in display order. Unknown keys
  /// mean the backend added a tag this client version renders generically.
  final Map<String, List<String>> dimensions;

  const StatsMeta({
    required this.ageBucketSize,
    required this.minAnswers,
    required this.dimensions,
  });
}
