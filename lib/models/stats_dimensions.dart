import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../utils/countries.dart';
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
  _ => Icons.label_outline,
};

/// Localized name for a dimension key.
String dimensionLabel(AppLocalizations l10n, String key) => switch (key) {
  'gender' => l10n.genderLabel,
  'age_bucket' => l10n.dimensionAge,
  'nationality' => l10n.dimensionNationality,
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
      'nationality' => countryDisplayName(l10n, value),
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
// mirror the backend's default contract: gender=m|w|d, age_bucket="<s>-<e>"
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

/// Fallback nationality codes: every country offered by the picker.
final List<StatsDimensionValue> _nationalityValues = [
  for (final country in countries)
    StatsDimensionValue(
      country.code,
      (l10n) => countryDisplayName(l10n, country.code),
    ),
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
];

String _genderDimensionLabel(AppLocalizations l10n) => l10n.genderLabel;
String _maleLabel(AppLocalizations l10n) => l10n.genderMale;
String _femaleLabel(AppLocalizations l10n) => l10n.genderFemale;
String _diverseLabel(AppLocalizations l10n) => l10n.genderDiverse;
String _ageDimensionLabel(AppLocalizations l10n) => l10n.dimensionAge;
String _nationalityDimensionLabel(AppLocalizations l10n) =>
    l10n.dimensionNationality;
