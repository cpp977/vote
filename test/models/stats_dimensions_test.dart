import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vote/l10n/app_localizations.dart';
import 'package:vote/models/answer_stats.dart';
import 'package:vote/models/stats_dimensions.dart';

/// Minimal mock of AppLocalizations for testing stats dimensions.
class _TestAppLocalizations extends AppLocalizations {
  _TestAppLocalizations() : super('en');

  @override
  String get genderLabel => 'Gender';

  @override
  String get genderMale => 'Male';

  @override
  String get genderFemale => 'Female';

  @override
  String get genderDiverse => 'Diverse';

  @override
  String get dimensionAge => 'Age';

  @override
  String get dimensionNationality => 'Nationality';

  @override
  String get dimensionRegion => 'Region';

  // noSuchMethod handles all other required methods
  @override
  dynamic noSuchMethod(Invocation invocation) => 'mock';
}

void main() {
  group('StatsDimension', () {
    group('dimensionIcon', () {
      test('returns correct icon for gender', () {
        expect(dimensionIcon('gender'), Icons.people_outline);
      });

      test('returns correct icon for age_bucket', () {
        expect(dimensionIcon('age_bucket'), Icons.calendar_today_outlined);
      });

      test('returns correct icon for nationality', () {
        expect(dimensionIcon('nationality'), Icons.public);
      });

      test('returns correct icon for region', () {
        expect(dimensionIcon('region'), Icons.map_outlined);
      });

      test('returns fallback icon for unknown key', () {
        expect(dimensionIcon('unknown'), Icons.label_outline);
      });
    });

    group('dimensionLabel', () {
      final l10n = _TestAppLocalizations();

      test('returns correct label for gender', () {
        expect(dimensionLabel(l10n, 'gender'), 'Gender');
      });

      test('returns correct label for age_bucket', () {
        expect(dimensionLabel(l10n, 'age_bucket'), 'Age');
      });

      test('returns correct label for nationality', () {
        expect(dimensionLabel(l10n, 'nationality'), 'Nationality');
      });

      test('returns correct label for region', () {
        expect(dimensionLabel(l10n, 'region'), 'Region');
      });

      test('returns key for unknown dimension', () {
        expect(dimensionLabel(l10n, 'unknown'), 'unknown');
      });
    });

    group('dimensionValueLabel', () {
      final l10n = _TestAppLocalizations();

      group('gender', () {
        test('returns Male for m', () {
          expect(dimensionValueLabel(l10n, 'gender', 'm'), 'Male');
        });

        test('returns Female for w', () {
          expect(dimensionValueLabel(l10n, 'gender', 'w'), 'Female');
        });

        test('returns Diverse for d', () {
          expect(dimensionValueLabel(l10n, 'gender', 'd'), 'Diverse');
        });

        test('returns raw value for unknown gender', () {
          expect(dimensionValueLabel(l10n, 'gender', 'x'), 'x');
        });
      });

      group('age_bucket', () {
        test('replaces hyphen with en dash', () {
          expect(dimensionValueLabel(l10n, 'age_bucket', '20-29'), '20–29');
        });

        test('handles single value', () {
          expect(dimensionValueLabel(l10n, 'age_bucket', '100'), '100');
        });
      });

      group('nationality', () {
        test('uppercases the value', () {
          expect(dimensionValueLabel(l10n, 'nationality', 'de'), 'DE');
        });

        test('uppercases already uppercase value', () {
          expect(dimensionValueLabel(l10n, 'nationality', 'US'), 'US');
        });
      });

      group('region', () {
        test('uppercases the value', () {
          expect(dimensionValueLabel(l10n, 'region', 'de-be'), 'DE-BE');
        });
      });

      group('unknown key', () {
        test('returns raw value', () {
          expect(dimensionValueLabel(l10n, 'unknown', 'value'), 'value');
        });
      });
    });

    group('statsDimensions (fallback registry)', () {
      test('contains four dimensions', () {
        expect(statsDimensions.length, 4);
      });

      test('dimensions have correct keys', () {
        final keys = statsDimensions.map((d) => d.key).toList();
        expect(keys, ['gender', 'age_bucket', 'nationality', 'region']);
      });

      test('gender dimension has correct values', () {
        final dim = statsDimensions.firstWhere((d) => d.key == 'gender');
        expect(dim.values.map((v) => v.value).toList(), ['m', 'w', 'd']);
      });

      test('age_bucket dimension has correct bucket count', () {
        final dim = statsDimensions.firstWhere((d) => d.key == 'age_bucket');
        expect(dim.values.length, 12); // 0-119 with size 10
      });

      test('nationality dimension has correct values', () {
        final dim = statsDimensions.firstWhere((d) => d.key == 'nationality');
        expect(dim.values.length, 10);
      });

      test('region dimension has correct values', () {
        final dim = statsDimensions.firstWhere((d) => d.key == 'region');
        expect(dim.values.length, 11);
      });
    });
  });

  group('dimensionsFromMeta', () {
    final l10n = _TestAppLocalizations();

    test('builds dimensions from meta', () {
      final meta = StatsMeta(
        ageBucketSize: 10,
        minAnswers: 5,
        dimensions: {
          'gender': ['m', 'w', 'd'],
          'age_bucket': ['0-9', '10-19'],
        },
      );

      final dimensions = dimensionsFromMeta(meta);

      expect(dimensions.length, 2);
      expect(dimensions[0].key, 'gender');
      expect(dimensions[0].values.map((v) => v.value).toList(), [
        'm',
        'w',
        'd',
      ]);
      expect(dimensions[1].key, 'age_bucket');
      expect(dimensions[1].values.map((v) => v.value).toList(), [
        '0-9',
        '10-19',
      ]);
    });

    test('uses fallback icon for known keys', () {
      final meta = StatsMeta(
        ageBucketSize: 10,
        minAnswers: 5,
        dimensions: {
          'gender': ['m'],
        },
      );

      final dimensions = dimensionsFromMeta(meta);
      expect(dimensions.first.icon, Icons.people_outline);
    });

    test('uses fallback icon for unknown keys', () {
      final meta = StatsMeta(
        ageBucketSize: 10,
        minAnswers: 5,
        dimensions: {
          'custom': ['a'],
        },
      );

      final dimensions = dimensionsFromMeta(meta);
      expect(dimensions.first.icon, Icons.label_outline);
    });

    test('uses fallback label for known keys', () {
      final meta = StatsMeta(
        ageBucketSize: 10,
        minAnswers: 5,
        dimensions: {
          'gender': ['m'],
        },
      );

      final dimensions = dimensionsFromMeta(meta);
      expect(dimensions.first.label(l10n), 'Gender');
    });

    test('uses key as label for unknown keys', () {
      final meta = StatsMeta(
        ageBucketSize: 10,
        minAnswers: 5,
        dimensions: {
          'custom': ['a'],
        },
      );

      final dimensions = dimensionsFromMeta(meta);
      expect(dimensions.first.label(l10n), 'custom');
    });

    test('generates correct value labels via dimensionValueLabel', () {
      final meta = StatsMeta(
        ageBucketSize: 10,
        minAnswers: 5,
        dimensions: {
          'gender': ['m', 'w'],
        },
      );

      final dimensions = dimensionsFromMeta(meta);
      final dim = dimensions.firstWhere((d) => d.key == 'gender');
      expect(dim.values[0].label(l10n), 'Male');
      expect(dim.values[1].label(l10n), 'Female');
    });
  });

  group('StatsDimensionValue', () {
    test('stores value and label function', () {
      final value = StatsDimensionValue('test', (l10n) => 'Label');
      expect(value.value, 'test');
      expect(value.label(_TestAppLocalizations()), 'Label');
    });
  });

  group('StatsDimension', () {
    test('stores all properties', () {
      final dim = StatsDimension(
        key: 'test',
        icon: Icons.star,
        label: (l10n) => 'Test',
        values: [StatsDimensionValue('a', (l10n) => 'A')],
      );

      expect(dim.key, 'test');
      expect(dim.icon, Icons.star);
      expect(dim.label(_TestAppLocalizations()), 'Test');
      expect(dim.values.length, 1);
    });
  });
}
