import '../utils/constants.dart';

import 'special_category.dart';

/// Represents a question in the voting system.
class Question {
  final int id;
  final String text;
  final int categoryId;
  final String categoryName;
  final String language;

  /// GDPR Art. 9 category of this question. [SpecialCategory.none] marks a
  /// regular question; every other value requires explicit user consent
  /// before it may be answered.
  final SpecialCategory specialCategory;

  Question({
    required this.id,
    required this.text,
    required this.categoryId,
    required this.categoryName,
    required this.language,
    this.specialCategory = SpecialCategory.none,
  });

  factory Question.fromJson(Map<String, dynamic> json) {
    return Question(
      id: json['id'] as int,
      text: json['text'] as String,
      categoryId: json['category_id'] as int,
      categoryName: json['category_name'] as String? ?? uncategorizedFallback,
      language: json['language'] as String? ?? 'en',
      specialCategory: SpecialCategory.fromLabel(
        json['special_category'] as String?,
      ),
    );
  }
}
