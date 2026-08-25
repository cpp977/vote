import 'package:flutter_test/flutter_test.dart';
import 'package:vote/models/answer_stats.dart';

void main() {
  group('StatsQuery', () {
    test('overall query has no filters', () {
      final query = StatsQuery.overall();
      expect(query.isOverall, isTrue);
      expect(query.filters, isEmpty);
      expect(query.valueOf('gender'), isNull);
    });

    test('withFilter adds a dimension filter', () {
      final query = StatsQuery.overall().withFilter('gender', 'm');
      expect(query.isOverall, isFalse);
      expect(query.filters, {'gender': 'm'});
    });

    test('withFilter replaces a previous value of the same dimension', () {
      final query = StatsQuery()
          .withFilter('gender', 'm')
          .withFilter('gender', 'w');
      expect(query.filters, {'gender': 'w'});
    });

    test('combinations across dimensions are supported', () {
      final query = StatsQuery()
          .withFilter('gender', 'm')
          .withFilter('age', '18-29')
          .withFilter('nationality', 'de');
      expect(query.isOverall, isFalse);
      expect(query.filters.length, 3);
    });

    test('withoutFilter removes only the given dimension', () {
      final base = StatsQuery()
          .withFilter('gender', 'm')
          .withFilter('age', '30-39');
      final reduced = base.withoutFilter('gender');
      expect(reduced.filters, {'age': '30-39'});
      expect(base.filters, {'gender': 'm', 'age': '30-39'});
    });

    test('withoutFilter returns the identical instance when unset', () {
      final query = StatsQuery().withFilter('gender', 'm');
      expect(identical(query.withoutFilter('age'), query), isTrue);
    });

    test('filters map is unmodifiable', () {
      final query = StatsQuery().withFilter('gender', 'm');
      expect(() => query.filters['age'] = 'u18', throwsUnsupportedError);
    });

    test('cacheKey is independent of insertion order', () {
      final a = StatsQuery()
          .withFilter('gender', 'm')
          .withFilter('nationality', 'de');
      final b = StatsQuery()
          .withFilter('nationality', 'de')
          .withFilter('gender', 'm');
      expect(a.cacheKey, b.cacheKey);
      expect(a, equals(b));
      expect(a.hashCode, b.hashCode);
    });

    test('different queries differ by cacheKey and equality', () {
      expect(
        StatsQuery().withFilter('gender', 'm'),
        isNot(equals(StatsQuery().withFilter('gender', 'w'))),
      );
      expect(StatsQuery(), isNot(equals(StatsQuery().withFilter('m', 'm'))));
    });
  });
}
