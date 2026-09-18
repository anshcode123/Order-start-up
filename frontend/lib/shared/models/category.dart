/// A menu category, scoped to the caller's own restaurant
/// (GET/POST/PUT/DELETE /api/restaurant/categories).
class Category {
  const Category({
    required this.id,
    required this.name,
    required this.description,
    required this.menuItemCount,
  });

  final String id;
  final String name;
  final String description;
  final int menuItemCount;

  factory Category.fromJson(Map<String, dynamic> json) {
    return Category(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String? ?? '',
      menuItemCount: json['menuItemCount'] as int? ?? 0,
    );
  }
}
