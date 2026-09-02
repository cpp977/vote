import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import 'answer_stats.dart';

/// A tag along which vote statistics can be resolved (e.g. gender, age).
///
/// Instances are UI-ready: they pair the wire-level key/values with icons and
/// localized label builders so filter UIs need no per-key knowledge.
class StatsDimension {
  /// Query parameter name used in statistics requests.
  final String key;

  /// Icon shown next to the dimension in filter UIs.
  final IconData icon;

  /// Localized dimension name.
  final String Function(AppLocalizations l10n) label;

  /// All values this dimension can be filtered by, in display order.
  final List<StatsDimensionValue> values;

  const StatsDimension({
    required this.key,
    required this.icon,
    required this.label,
    required this.values,
  });
}

/// One selectable value within a [StatsDimension].
class StatsDimensionValue {
  /// Wire value sent to the backend as the query parameter value.
  final String value;

  /// Resolves the localized display label.
  final String Function(AppLocalizations l10n) label;

  const StatsDimensionValue(this.value, this.label);
}

// ─── Presentation helpers ──────────────────────────────────────────────────
//
// The backend owns the set of dimensions and their allowed values (exposed
// via GET /stats/meta). These helpers attach presentation to whatever keys
// arrive; unknown keys fall back to generic icons and raw labels.

/// Icon for a dimension key; generic fallback for keys added server-side
/// without a matching presentation here.
IconData dimensionIcon(String key) => switch (key) {
  'gender' => Icons.people_outline,
  'age_bucket' => Icons.calendar_today_outlined,
  'nationality' => Icons.public,
  'region' => Icons.map_outlined,
  _ => Icons.label_outline,
};

/// Localized name for a dimension key.
String dimensionLabel(AppLocalizations l10n, String key) => switch (key) {
  'gender' => l10n.genderLabel,
  'age_bucket' => l10n.dimensionAge,
  'nationality' => l10n.dimensionNationality,
  'region' => l10n.dimensionRegion,
  _ => key,
};

/// Localized label for one wire value of a dimension.
String dimensionValueLabel(AppLocalizations l10n, String key, String value) =>
    switch (key) {
      'gender' => switch (value) {
        'm' => l10n.genderMale,
        'w' => l10n.genderFemale,
        'd' => l10n.genderDiverse,
        _ => value,
      },
      // Ranges such as "20-29" render language-neutrally with an en dash.
      'age_bucket' => value.replaceFirst('-', '–'),
      'nationality' => value.toUpperCase(),
      'region' => value.toUpperCase(),
      _ => value,
    };

/// Builds UI-ready dimensions from metadata fetched from `/stats/meta`.
List<StatsDimension> dimensionsFromMeta(StatsMeta meta) {
  return [
    for (final MapEntry(key: key, value: values) in meta.dimensions.entries)
      StatsDimension(
        key: key,
        icon: dimensionIcon(key),
        label: (l10n) => dimensionLabel(l10n, key),
        values: [
          for (final value in values)
            StatsDimensionValue(
              value,
              (l10n) => dimensionValueLabel(l10n, key, value),
            ),
        ],
      ),
  ];
}

// ─── Built-in fallback registry ────────────────────────────────────────────
//
// Used until metadata has loaded (or when the endpoint is unreachable). Must
// mirror the backend's default contract: gender=m|w|d, age_bucket="-<e>"
// decades, nationality=ISO 3166-1 alpha-2 codes.

/// Age range covered by the fallback bucket labels (matches the backend).
const int _fallbackMaxAge = 119;

/// Default bucket width of the backend (config.json: age_bucket_size).
const int _defaultBucketSize = 10;

List<StatsDimensionValue> _ageBucketValues(int size) => [
  for (int start = 0; start <= _fallbackMaxAge; start += size)
    StatsDimensionValue('$start-${start + size - 1}', (l10n) {
      final end = start + size - 1 > _fallbackMaxAge
          ? _fallbackMaxAge
          : start + size - 1;
      return '$start–$end';
    }),
];

/// Fallback nationality codes: a small set of common countries.
final List<StatsDimensionValue> _nationalityValues = [
  StatsDimensionValue('DE', (l10n) => 'Germany'),
  StatsDimensionValue('AT', (l10n) => 'Austria'),
  StatsDimensionValue('CH', (l10n) => 'Switzerland'),
  StatsDimensionValue('FR', (l10n) => 'France'),
  StatsDimensionValue('IT', (l10n) => 'Italy'),
  StatsDimensionValue('ES', (l10n) => 'Spain'),
  StatsDimensionValue('NL', (l10n) => 'Netherlands'),
  StatsDimensionValue('PL', (l10n) => 'Poland'),
  StatsDimensionValue('US', (l10n) => 'United States'),
  StatsDimensionValue('GB', (l10n) => 'United Kingdom'),
];

/// Fallback region codes: a small set of common regions.
final List<StatsDimensionValue> _regionValues = [
  StatsDimensionValue('DE-BE', (l10n) => 'Berlin'),
  StatsDimensionValue('DE-BY', (l10n) => 'Bavaria'),
  StatsDimensionValue('DE-NW', (l10n) => 'North Rhine-Westphalia'),
  StatsDimensionValue('AT-9', (l10n) => 'Vienna'),
  StatsDimensionValue('CH-ZH', (l10n) => 'Zurich'),
  StatsDimensionValue('FR-IDF', (l10n) => 'Île-de-France'),
  StatsDimensionValue('IT-62', (l10n) => 'Lazio'),
  StatsDimensionValue('ES-MD', (l10n) => 'Madrid'),
  StatsDimensionValue('US-CA', (l10n) => 'California'),
  StatsDimensionValue('US-NY', (l10n) => 'New York'),
  StatsDimensionValue('GB-ENG', (l10n) => 'England'),
];

final List<StatsDimension> statsDimensions = [
  const StatsDimension(
    key: 'gender',
    icon: Icons.people_outline,
    label: _genderDimensionLabel,
    values: [
      StatsDimensionValue('m', _maleLabel),
      StatsDimensionValue('w', _femaleLabel),
      StatsDimensionValue('d', _diverseLabel),
    ],
  ),
  StatsDimension(
    key: 'age_bucket',
    icon: Icons.calendar_today_outlined,
    label: _ageDimensionLabel,
    values: _ageBucketValues(_defaultBucketSize),
  ),
  StatsDimension(
    key: 'nationality',
    icon: Icons.public,
    label: _nationalityDimensionLabel,
    values: _nationalityValues,
  ),
  StatsDimension(
    key: 'region',
    icon: Icons.map_outlined,
    label: _regionDimensionLabel,
    values: _regionValues,
  ),
];

String _genderDimensionLabel(AppLocalizations l10n) => l10n.genderLabel;
String _maleLabel(AppLocalizations l10n) => l10n.genderMale;
String _femaleLabel(AppLocalizations l10n) => l10n.genderFemale;
String _diverseLabel(AppLocalizations l10n) => l10n.genderDiverse;
String _ageDimensionLabel(AppLocalizations l10n) => l10n.dimensionAge;
String _nationalityDimensionLabel(AppLocalizations l10n) =>
    l10n.dimensionNationality;
String _regionDimensionLabel(AppLocalizations l10n) => l10n.dimensionRegion;
