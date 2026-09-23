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
    this.whatsappNumber,
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
  final String? whatsappNumber;
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
      whatsappNumber: json['whatsappNumber'] as String?,
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
      restaurant:
          Restaurant.fromJson(json['restaurant'] as Map<String, dynamic>),
      admin: json['admin'] != null
          ? RestaurantAdminSummary.fromJson(
              json['admin'] as Map<String, dynamic>)
          : null,
      menuUrl: json['menuUrl'] as String,
    );
  }
}

/// Stats + recent restaurants for the Super Admin dashboard
/// (GET /api/super-admin/dashboard/stats or /api/admin/dashboard).
class SuperAdminDashboard {
  const SuperAdminDashboard({
    required this.totalRestaurants,
    required this.activeRestaurants,
    required this.inactiveRestaurants,
    required this.totalOrders,
    required this.todayOrders,
    required this.pendingOrders,
    required this.completedOrders,
    required this.recentRestaurants,
  });

  final int totalRestaurants;
  final int activeRestaurants;
  final int inactiveRestaurants;
  final int totalOrders;
  final int todayOrders;
  final int pendingOrders;
  final int completedOrders;
  final List<Restaurant> recentRestaurants;

  factory SuperAdminDashboard.fromJson(Map<String, dynamic> json) {
    final stats = json['stats'] as Map<String, dynamic>? ?? {};
    final recent =
        (json['recentRestaurants'] as List?)?.cast<Map<String, dynamic>>() ??
            [];
    return SuperAdminDashboard(
      totalRestaurants: (stats['totalRestaurants'] as int?) ?? 0,
      activeRestaurants: (stats['activeRestaurants'] as int?) ?? 0,
      inactiveRestaurants: (stats['inactiveRestaurants'] as int?) ?? 0,
      totalOrders: (stats['totalOrders'] as int?) ?? 0,
      todayOrders: (stats['todayOrders'] as int?) ?? 0,
      pendingOrders: (stats['pendingOrders'] as int?) ?? 0,
      completedOrders: (stats['completedOrders'] as int?) ?? 0,
      recentRestaurants: recent.map(Restaurant.fromJson).toList(),
    );
  }
}

/// Platform Order Analytics model
class OrderAnalytics {
  const OrderAnalytics({
    required this.totalOrders,
    required this.todayOrders,
    required this.thisWeekOrders,
    required this.thisMonthOrders,
    required this.filteredOrders,
    required this.filteredRevenue,
    required this.statusBreakdown,
    required this.restaurants,
  });

  final int totalOrders;
  final int todayOrders;
  final int thisWeekOrders;
  final int thisMonthOrders;
  final int filteredOrders;
  final String filteredRevenue;
  final Map<String, int> statusBreakdown;
  final List<RestaurantOrderStats> restaurants;

  factory OrderAnalytics.fromJson(Map<String, dynamic> json) {
    final summary = json['summary'] as Map<String, dynamic>? ?? {};
    final rawBreakdown = json['statusBreakdown'] as Map<String, dynamic>? ?? {};
    final breakdown =
        rawBreakdown.map((k, v) => MapEntry(k, (v as num).toInt()));
    final rawRestaurants =
        (json['restaurants'] as List?)?.cast<Map<String, dynamic>>() ?? [];

    return OrderAnalytics(
      totalOrders: (summary['totalOrders'] as int?) ?? 0,
      todayOrders: (summary['todayOrders'] as int?) ?? 0,
      thisWeekOrders: (summary['thisWeekOrders'] as int?) ?? 0,
      thisMonthOrders: (summary['thisMonthOrders'] as int?) ?? 0,
      filteredOrders: (summary['filteredOrders'] as int?) ?? 0,
      filteredRevenue: (summary['filteredRevenue'] as String?) ?? '0',
      statusBreakdown: breakdown,
      restaurants: rawRestaurants.map(RestaurantOrderStats.fromJson).toList(),
    );
  }
}

/// Per-restaurant order stats in platform analytics
class RestaurantOrderStats {
  const RestaurantOrderStats({
    required this.id,
    required this.name,
    required this.slug,
    required this.isActive,
    required this.totalOrders,
    required this.todayOrders,
    required this.pendingOrders,
    required this.completedOrders,
    this.phone,
    this.email,
  });

  final String id;
  final String name;
  final String slug;
  final bool isActive;
  final int totalOrders;
  final int todayOrders;
  final int pendingOrders;
  final int completedOrders;
  final String? phone;
  final String? email;

  factory RestaurantOrderStats.fromJson(Map<String, dynamic> json) {
    return RestaurantOrderStats(
      id: json['id'] as String,
      name: json['name'] as String,
      slug: json['slug'] as String,
      isActive: (json['isActive'] as bool?) ?? true,
      totalOrders: (json['totalOrders'] as int?) ?? 0,
      todayOrders: (json['todayOrders'] as int?) ?? 0,
      pendingOrders: (json['pendingOrders'] as int?) ?? 0,
      completedOrders: (json['completedOrders'] as int?) ?? 0,
      phone: json['phone'] as String?,
      email: json['email'] as String?,
    );
  }
}

/// Usage statistics for a specific restaurant
class RestaurantUsageStats {
  const RestaurantUsageStats({
    required this.totalCategories,
    required this.totalMenuItems,
    required this.availableMenuItems,
    required this.unavailableMenuItems,
    required this.totalOrders,
    required this.todayOrders,
    required this.pendingOrders,
    required this.completedOrders,
    required this.totalRevenue,
    required this.statusBreakdown,
  });

  final int totalCategories;
  final int totalMenuItems;
  final int availableMenuItems;
  final int unavailableMenuItems;
  final int totalOrders;
  final int todayOrders;
  final int pendingOrders;
  final int completedOrders;
  final String totalRevenue;
  final Map<String, int> statusBreakdown;

  factory RestaurantUsageStats.fromJson(Map<String, dynamic> json) {
    final stats = json['stats'] as Map<String, dynamic>? ?? {};
    final rawBreakdown =
        stats['statusBreakdown'] as Map<String, dynamic>? ?? {};
    final breakdown =
        rawBreakdown.map((k, v) => MapEntry(k, (v as num).toInt()));

    return RestaurantUsageStats(
      totalCategories: (stats['totalCategories'] as int?) ?? 0,
      totalMenuItems: (stats['totalMenuItems'] as int?) ?? 0,
      availableMenuItems: (stats['availableMenuItems'] as int?) ?? 0,
      unavailableMenuItems: (stats['unavailableMenuItems'] as int?) ?? 0,
      totalOrders: (stats['totalOrders'] as int?) ?? 0,
      todayOrders: (stats['todayOrders'] as int?) ?? 0,
      pendingOrders: (stats['pendingOrders'] as int?) ?? 0,
      completedOrders: (stats['completedOrders'] as int?) ?? 0,
      totalRevenue: (stats['totalRevenue'] as String?) ?? '0',
      statusBreakdown: breakdown,
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
