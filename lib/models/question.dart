import '../utils/constants.dart';

/// Represents a question in the voting system.
class Question {
  final int id;
  final String text;
  final int categoryId;
  final String categoryName;
  final String language;

  Question({
    required this.id,
    required this.text,
    required this.categoryId,
    required this.categoryName,
    required this.language,
  });

  factory Question.fromJson(Map<String, dynamic> json) {
    return Question(
      id: json['id'] as int,
      text: json['text'] as String,
      categoryId: json['category_id'] as int,
      categoryName: json['category_name'] as String? ?? uncategorizedFallback,
      language: json['language'] as String? ?? 'en',
    );
  }
}
