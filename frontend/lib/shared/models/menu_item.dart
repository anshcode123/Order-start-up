/// A menu item, scoped to the caller's own restaurant
/// (GET/POST/PUT/DELETE /api/restaurant/menu-items).
class MenuItem {
  const MenuItem({
    required this.id,
    required this.name,
    required this.description,
    required this.price,
    required this.imageUrl,
    required this.isAvailable,
    required this.categoryId,
    required this.categoryName,
  });

  final String id;
  final String name;
  final String description;
  // Kept as a String end-to-end (matches the backend's Decimal, sent as
  // a string) so display never round-trips through a Dart double.
  final String price;
  final String? imageUrl;
  final bool isAvailable;
  final String categoryId;
  final String? categoryName;

  factory MenuItem.fromJson(Map<String, dynamic> json) {
    return MenuItem(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String? ?? '',
      price: json['price'] as String,
      imageUrl: json['imageUrl'] as String?,
      isAvailable: json['isAvailable'] as bool? ?? true,
      categoryId: json['categoryId'] as String,
      categoryName: json['categoryName'] as String?,
    );
  }

  /// For display only - e.g. "299.00". Formatting/currency symbol is the
  /// caller's job.
  String get formattedPrice => price;
}
