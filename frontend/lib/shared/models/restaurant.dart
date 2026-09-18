/// A restaurant as returned by the /api/admin/restaurants endpoints.
/// Not every field is present on every response (the list endpoint is
/// slimmer than the detail endpoint), so everything but id/name/slug is
/// nullable.
class Restaurant {
  const Restaurant({
    required this.id,
    required this.name,
    required this.slug,
    required this.isActive,
    this.description,
    this.phone,
    this.email,
    this.address,
    this.adminEmail,
    this.createdAt,
  });

  final String id;
  final String name;
  final String slug;
  final bool isActive;
  final String? description;
  final String? phone;
  final String? email;
  final String? address;
  final String? adminEmail;
  final DateTime? createdAt;

  factory Restaurant.fromJson(Map<String, dynamic> json) {
    return Restaurant(
      id: json['id'] as String,
      name: json['name'] as String,
      slug: json['slug'] as String,
      isActive: json['isActive'] as bool? ?? true,
      description: json['description'] as String?,
      phone: json['phone'] as String?,
      email: json['email'] as String?,
      address: json['address'] as String?,
      adminEmail: json['adminEmail'] as String?,
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'] as String)
          : null,
    );
  }
}

/// The admin summary returned alongside a single restaurant by
/// GET /api/admin/restaurants/:id.
class RestaurantAdminSummary {
  const RestaurantAdminSummary({
    required this.id,
    required this.name,
    required this.email,
  });

  final String id;
  final String name;
  final String email;

  factory RestaurantAdminSummary.fromJson(Map<String, dynamic> json) {
    return RestaurantAdminSummary(
      id: json['id'] as String,
      name: json['name'] as String,
      email: json['email'] as String,
    );
  }
}

/// Full payload returned by GET /api/admin/restaurants/:id: the
/// restaurant, its admin (if any), and the customer menu URL.
class RestaurantDetail {
  const RestaurantDetail({
    required this.restaurant,
    required this.admin,
    required this.menuUrl,
  });

  final Restaurant restaurant;
  final RestaurantAdminSummary? admin;
  final String menuUrl;

  factory RestaurantDetail.fromJson(Map<String, dynamic> json) {
    return RestaurantDetail(
      restaurant: Restaurant.fromJson(json['restaurant'] as Map<String, dynamic>),
      admin: json['admin'] != null
          ? RestaurantAdminSummary.fromJson(json['admin'] as Map<String, dynamic>)
          : null,
      menuUrl: json['menuUrl'] as String,
    );
  }
}

/// Stats + recent restaurants for the Super Admin dashboard
/// (GET /api/admin/dashboard).
class SuperAdminDashboard {
  const SuperAdminDashboard({
    required this.totalRestaurants,
    required this.activeRestaurants,
    required this.inactiveRestaurants,
    required this.recentRestaurants,
  });

  final int totalRestaurants;
  final int activeRestaurants;
  final int inactiveRestaurants;
  final List<Restaurant> recentRestaurants;

  factory SuperAdminDashboard.fromJson(Map<String, dynamic> json) {
    final stats = json['stats'] as Map<String, dynamic>;
    final recent = (json['recentRestaurants'] as List).cast<Map<String, dynamic>>();
    return SuperAdminDashboard(
      totalRestaurants: stats['totalRestaurants'] as int,
      activeRestaurants: stats['activeRestaurants'] as int,
      inactiveRestaurants: stats['inactiveRestaurants'] as int,
      recentRestaurants: recent.map(Restaurant.fromJson).toList(),
    );
  }
}

/// Result of POST /api/admin/restaurants - what the "Restaurant Created
/// Successfully" screen needs.
class CreatedRestaurantResult {
  const CreatedRestaurantResult({
    required this.restaurantId,
    required this.restaurantName,
    required this.adminEmail,
    required this.menuUrl,
  });

  final String restaurantId;
  final String restaurantName;
  final String adminEmail;
  final String menuUrl;

  factory CreatedRestaurantResult.fromJson(Map<String, dynamic> json) {
    final restaurant = json['restaurant'] as Map<String, dynamic>;
    final admin = json['admin'] as Map<String, dynamic>;
    return CreatedRestaurantResult(
      restaurantId: restaurant['id'] as String,
      restaurantName: restaurant['name'] as String,
      adminEmail: admin['email'] as String,
      menuUrl: json['menuUrl'] as String,
    );
  }
}
