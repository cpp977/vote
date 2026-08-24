import 'package:flutter_test/flutter_test.dart';
import 'package:vote/models/special_category.dart';

void main() {
  group('SpecialCategory', () {
    test('fromLabel maps every known database label', () {
      expect(SpecialCategory.fromLabel('none'), SpecialCategory.none);
      expect(
        SpecialCategory.fromLabel('racial_or_ethnic_origin'),
        SpecialCategory.racialOrEthnicOrigin,
      );
      expect(
        SpecialCategory.fromLabel('political_opinion'),
        SpecialCategory.politicalOpinion,
      );
      expect(
        SpecialCategory.fromLabel('religious_or_philosophical_belief'),
        SpecialCategory.religiousOrPhilosophicalBelief,
      );
      expect(
        SpecialCategory.fromLabel('trade_union_membership'),
        SpecialCategory.tradeUnionMembership,
      );
      expect(
        SpecialCategory.fromLabel('genetic_data'),
        SpecialCategory.geneticData,
      );
      expect(
        SpecialCategory.fromLabel('biometric_data'),
        SpecialCategory.biometricData,
      );
      expect(SpecialCategory.fromLabel('health'), SpecialCategory.health);
      expect(
        SpecialCategory.fromLabel('sex_life_or_orientation'),
        SpecialCategory.sexLifeOrOrientation,
      );
      expect(
        SpecialCategory.fromLabel('criminal_convictions'),
        SpecialCategory.criminalConvictions,
      );
    });

    test('fromLabel falls back to none for unknown or missing labels', () {
      expect(SpecialCategory.fromLabel('something_new'), SpecialCategory.none);
      expect(SpecialCategory.fromLabel(''), SpecialCategory.none);
      expect(SpecialCategory.fromLabel(null), SpecialCategory.none);
    });

    test('label round-trips through fromLabel for every value', () {
      for (final category in SpecialCategory.values) {
        expect(
          SpecialCategory.fromLabel(category.label),
          category,
          reason: '${category.label} should round-trip',
        );
      }
    });

    test('labels match the backend snake_case spelling', () {
      expect(SpecialCategory.none.label, 'none');
      expect(SpecialCategory.health.label, 'health');
      expect(
        SpecialCategory.sexLifeOrOrientation.label,
        'sex_life_or_orientation',
      );
      expect(SpecialCategory.criminalConvictions.label, 'criminal_convictions');
    });
  });
}
