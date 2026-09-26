import 'package:scanserve/shared/models/menu_item.dart';

class PublicRestaurant {
  const PublicRestaurant({
    required this.id,
    required this.name,
    required this.slug,
    required this.description,
    required this.phone,
    required this.address,
    this.logoUrl,
    this.requireTableNumber = true,
  });

  final String id;
  final String name;
  final String slug;
  final String description;
  final String phone;
  final String address;
  final String? logoUrl;
  final bool requireTableNumber;

  factory PublicRestaurant.fromJson(Map<String, dynamic> json) {
    return PublicRestaurant(
      id: json['id'] as String,
      name: json['name'] as String,
      slug: json['slug'] as String,
      description: (json['description'] as String?) ?? '',
      phone: (json['phone'] as String?) ?? '',
      address: (json['address'] as String?) ?? '',
      logoUrl: json['logoUrl'] as String?,
      requireTableNumber: (json['requireTableNumber'] as bool?) ?? true,
    );
  }
}

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
      description: (json['description'] as String?) ?? '',
      items: itemsJson.map(MenuItem.fromJson).toList(),
    );
  }
}

class PublicMenu {
  const PublicMenu({
    required this.restaurant,
    required this.categories,
  });

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
