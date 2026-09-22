import 'package:scanserve/shared/models/menu_item.dart';

/// Public-safe restaurant info from GET /api/public/menu/:restaurantSlug.
/// Deliberately slimmer than the admin-facing Restaurant model - no
/// isActive, no email, nothing that isn't meant for a customer to see.
class PublicRestaurant {
  const PublicRestaurant({
    required this.id,
    required this.name,
    required this.slug,
    required this.description,
    required this.phone,
    required this.address,
  });

  final String id;
  final String name;
  final String slug;
  final String description;
  final String phone;
  final String address;

  factory PublicRestaurant.fromJson(Map<String, dynamic> json) {
    return PublicRestaurant(
      id: json['id'] as String,
      name: json['name'] as String,
      slug: json['slug'] as String,
      description: json['description'] as String? ?? '',
      phone: json['phone'] as String? ?? '',
      address: json['address'] as String? ?? '',
    );
  }
}

/// A category with only its available items nested inline - matches the
/// shape GET /api/public/menu/:restaurantSlug returns, built specifically
/// for how the public menu screen renders (category sections, each
/// holding the items to show under it).
class PublicMenuCategory {
  const PublicMenuCategory({
    required this.id,
    required this.name,
    required this.description,
    required this.items,
  });

  final String id;
  final String name;
  final String description;
  final List<MenuItem> items;

  factory PublicMenuCategory.fromJson(Map<String, dynamic> json) {
    final itemsJson = (json['items'] as List).cast<Map<String, dynamic>>();
    return PublicMenuCategory(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String? ?? '',
      items: itemsJson.map(MenuItem.fromJson).toList(),
    );
  }
}

/// The full public menu payload: restaurant + its categories/items.
class PublicMenu {
  const PublicMenu({required this.restaurant, required this.categories});

  final PublicRestaurant restaurant;
  final List<PublicMenuCategory> categories;

  factory PublicMenu.fromJson(Map<String, dynamic> json) {
    final categoriesJson = (json['categories'] as List).cast<Map<String, dynamic>>();
    return PublicMenu(
      restaurant: PublicRestaurant.fromJson(json['restaurant'] as Map<String, dynamic>),
      categories: categoriesJson.map(PublicMenuCategory.fromJson).toList(),
    );
  }
}
