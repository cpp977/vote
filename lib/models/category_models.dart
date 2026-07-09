/// Model representing a question category returned by the backend.
class Category {
  final int id;
  final String name;

  const Category({required this.id, required this.name});

  /// Creates a [Category] from a JSON object as returned by `GET /categories`.
  factory Category.fromJson(Map<String, dynamic> json) {
    return Category(id: json['id'] as int, name: json['name'] as String? ?? '');
  }
}
