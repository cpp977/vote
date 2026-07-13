/// Model representing a question category returned by the backend.
class Category {
  final int id;
  final String name;
  final String language;

  const Category({
    required this.id,
    required this.name,
    required this.language,
  });

  /// Creates a [Category] from a JSON object as returned by
  /// `GET /categories/lang/{lang}`.
  factory Category.fromJson(Map<String, dynamic> json) {
    return Category(
      id: json['id'] as int,
      name: json['name'] as String? ?? '',
      language: json['language'] as String? ?? '',
    );
  }
}
