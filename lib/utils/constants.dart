import 'package:flutter/material.dart';

/// Fallback category name used by [Question.fromJson] when the backend
/// returns none. It is matched (case-sensitively) at the display site so the
/// localized equivalent can be shown instead.
const String uncategorizedFallback = 'Uncategorized';

/// Number of questions requested per page from the backend.
const int pageSize = 20;

/// Debounce delay for search input in milliseconds.
const int searchDelayMilliseconds = 500;

/// Distinct colors for answer bars — cycles through the list.
const List<Color> answerColors = [
  Color(0xFF6750A4), // Purple
  Color(0xFF0061A4), // Blue
  Color(0xFF006E60), // Teal
  Color(0xFF7D5260), // Rose
  Color(0xFF8C4A60), // Mauve
  Color(0xFF4C662B), // Green
  Color(0xFF8B6914), // Gold
  Color(0xFF984061), // Crimson
];
