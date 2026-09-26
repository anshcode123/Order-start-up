class MenuItemVariant {
  const MenuItemVariant({
    required this.id,
    required this.name,
    required this.price,
    this.sortOrder = 0,
    this.isAvailable = true,
  });

  final String id;
  final String name;
  final String price;
  final int sortOrder;
  final bool isAvailable;

  double get numericPrice => double.tryParse(price) ?? 0.0;

  String get formattedPrice => '₹${numericPrice.toStringAsFixed(2)}';

  factory MenuItemVariant.fromJson(Map<String, dynamic> json) {
    return MenuItemVariant(
      id: (json['id'] as String?) ?? '',
      name: (json['name'] as String?) ?? '',
      price: json['price'].toString(),
      sortOrder: (json['sortOrder'] as num?)?.toInt() ?? 0,
      isAvailable: (json['isAvailable'] as bool?) ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id.isNotEmpty) 'id': id,
      'name': name,
      'price': price,
      'sortOrder': sortOrder,
      'isAvailable': isAvailable,
    };
  }
}

/// A menu item. `price` comes back from the backend as a string (Prisma
/// Decimal serialized safely) so we keep the raw string for display and
/// parse on demand when we need to format it.
class MenuItem {
  const MenuItem({
    required this.id,
    required this.name,
    required this.description,
    required this.price,
    required this.imageUrl,
    required this.isAvailable,
    required this.categoryId,
    this.categoryName,
    this.hasVariants = false,
    this.variants = const [],
  });

  final String id;
  final String name;
  final String description;
  final String price;
  final String? imageUrl;
  final bool isAvailable;
  final String categoryId;
  final String? categoryName;
  final bool hasVariants;
  final List<MenuItemVariant> variants;

  double get numericPrice => double.tryParse(price) ?? 0.0;

  String get formattedPrice => '₹${numericPrice.toStringAsFixed(2)}';

  String get formattedPriceSummary {
    if (hasVariants && variants.isNotEmpty) {
      return variants
          .map((v) => '${v.name}: ${v.formattedPrice}${v.isAvailable ? '' : ' (Unavailable)'}')
          .join('  •  ');
    }
    return formattedPrice;
  }

  factory MenuItem.fromJson(Map<String, dynamic> json) {
    final rawVariants = (json['variants'] as List?)?.cast<Map<String, dynamic>>() ?? const [];
    return MenuItem(
      id: json['id'] as String,
      name: json['name'] as String,
      description: (json['description'] as String?) ?? '',
      price: json['price'].toString(),
      imageUrl: json['imageUrl'] as String?,
      // Public menu payloads omit `isAvailable` because the endpoint
      // already filters to available-only items.
      isAvailable: (json['isAvailable'] as bool?) ?? true,
      categoryId: json['categoryId'] as String,
      categoryName: json['categoryName'] as String?,
      hasVariants: (json['hasVariants'] as bool?) ?? false,
      variants: rawVariants.map(MenuItemVariant.fromJson).toList(),
    );
  }
}
