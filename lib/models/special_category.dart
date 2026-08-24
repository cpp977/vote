/// Special (GDPR Art. 9) category of a question.
///
/// Mirrors the PostgreSQL enum type `special_category_type` of the backend.
/// [none] marks regular questions that can be answered without consent;
/// every other value marks a sensitive topic that requires explicit user
/// consent before answering.
enum SpecialCategory {
  none,
  racialOrEthnicOrigin,
  politicalOpinion,
  religiousOrPhilosophicalBelief,
  tradeUnionMembership,
  geneticData,
  biometricData,
  health,
  sexLifeOrOrientation,
  criminalConvictions;

  /// Parses a database label into its enumerator.
  ///
  /// Unknown labels map to [none], mirroring the lenient handling of the
  /// backend model.
  static SpecialCategory fromLabel(String? label) => switch (label) {
    'racial_or_ethnic_origin' => racialOrEthnicOrigin,
    'political_opinion' => politicalOpinion,
    'religious_or_philosophical_belief' => religiousOrPhilosophicalBelief,
    'trade_union_membership' => tradeUnionMembership,
    'genetic_data' => geneticData,
    'biometric_data' => biometricData,
    'health' => health,
    'sex_life_or_orientation' => sexLifeOrOrientation,
    'criminal_convictions' => criminalConvictions,
    _ => none,
  };

  /// The database label of this enumerator (as sent to and received from the
  /// backend).
  String get label => switch (this) {
    SpecialCategory.none => 'none',
    SpecialCategory.racialOrEthnicOrigin => 'racial_or_ethnic_origin',
    SpecialCategory.politicalOpinion => 'political_opinion',
    SpecialCategory.religiousOrPhilosophicalBelief =>
      'religious_or_philosophical_belief',
    SpecialCategory.tradeUnionMembership => 'trade_union_membership',
    SpecialCategory.geneticData => 'genetic_data',
    SpecialCategory.biometricData => 'biometric_data',
    SpecialCategory.health => 'health',
    SpecialCategory.sexLifeOrOrientation => 'sex_life_or_orientation',
    SpecialCategory.criminalConvictions => 'criminal_convictions',
  };
}
