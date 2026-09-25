class SubscriptionPlan {
  final String id;
  final String name;
  final String priceMonthly;
  final int? maxCategories;
  final int? maxMenuItems;
  final bool whatsappEnabled;
  final bool analyticsEnabled;
  final bool isActive;

  const SubscriptionPlan({
    required this.id,
    required this.name,
    required this.priceMonthly,
    this.maxCategories,
    this.maxMenuItems,
    required this.whatsappEnabled,
    required this.analyticsEnabled,
    required this.isActive,
  });

  factory SubscriptionPlan.fromJson(Map<String, dynamic> json) {
    return SubscriptionPlan(
      id: json['id'] as String,
      name: json['name'] as String,
      priceMonthly: (json['priceMonthly'] ?? '0').toString(),
      maxCategories: json['maxCategories'] as int?,
      maxMenuItems: json['maxMenuItems'] as int?,
      whatsappEnabled: json['whatsappEnabled'] as bool? ?? false,
      analyticsEnabled: json['analyticsEnabled'] as bool? ?? false,
      isActive: json['isActive'] as bool? ?? true,
    );
  }
}

class SubscriptionUsage {
  final int categoriesUsed;
  final int? maxCategories;
  final int menuItemsUsed;
  final int? maxMenuItems;

  const SubscriptionUsage({
    required this.categoriesUsed,
    this.maxCategories,
    required this.menuItemsUsed,
    this.maxMenuItems,
  });

  factory SubscriptionUsage.fromJson(Map<String, dynamic> json) {
    return SubscriptionUsage(
      categoriesUsed: (json['categoriesUsed'] as num?)?.toInt() ?? 0,
      maxCategories: (json['maxCategories'] as num?)?.toInt(),
      menuItemsUsed: (json['menuItemsUsed'] as num?)?.toInt() ?? 0,
      maxMenuItems: (json['maxMenuItems'] as num?)?.toInt(),
    );
  }
}

class RestaurantSubscription {
  final String id;
  final String restaurantId;
  final String? restaurantName;
  final String? restaurantSlug;
  final bool? restaurantIsActive;
  final SubscriptionPlan plan;
  final String status;
  final DateTime startDate;
  final DateTime? endDate;
  final DateTime? trialEndsAt;
  final int? daysRemaining;
  final String? notes;
  final SubscriptionUsage? usage;

  const RestaurantSubscription({
    required this.id,
    required this.restaurantId,
    this.restaurantName,
    this.restaurantSlug,
    this.restaurantIsActive,
    required this.plan,
    required this.status,
    required this.startDate,
    this.endDate,
    this.trialEndsAt,
    this.daysRemaining,
    this.notes,
    this.usage,
  });

  factory RestaurantSubscription.fromJson(Map<String, dynamic> json) {
    final restaurantMap = json['restaurant'] as Map<String, dynamic>?;
    return RestaurantSubscription(
      id: json['id'] as String,
      restaurantId: json['restaurantId'] as String,
      restaurantName: restaurantMap?['name'] as String?,
      restaurantSlug: restaurantMap?['slug'] as String?,
      restaurantIsActive: restaurantMap?['isActive'] as bool?,
      plan: SubscriptionPlan.fromJson(json['plan'] as Map<String, dynamic>),
      status: json['status'] as String? ?? 'TRIAL',
      startDate: DateTime.parse(json['startDate'] as String),
      endDate: json['endDate'] != null ? DateTime.tryParse(json['endDate'] as String) : null,
      trialEndsAt: json['trialEndsAt'] != null ? DateTime.tryParse(json['trialEndsAt'] as String) : null,
      daysRemaining: (json['daysRemaining'] as num?)?.toInt(),
      notes: json['notes'] as String?,
      usage: json['usage'] != null
          ? SubscriptionUsage.fromJson(json['usage'] as Map<String, dynamic>)
          : null,
    );
  }
}

class SubscriptionOverviewSummary {
  final int totalSubscriptions;
  final int activeSubscriptions;
  final int trialSubscriptions;
  final int expiredSubscriptions;
  final int suspendedSubscriptions;
  final int cancelledSubscriptions;

  const SubscriptionOverviewSummary({
    required this.totalSubscriptions,
    required this.activeSubscriptions,
    required this.trialSubscriptions,
    required this.expiredSubscriptions,
    required this.suspendedSubscriptions,
    required this.cancelledSubscriptions,
  });

  factory SubscriptionOverviewSummary.fromJson(Map<String, dynamic> json) {
    return SubscriptionOverviewSummary(
      totalSubscriptions: (json['totalSubscriptions'] as num?)?.toInt() ?? 0,
      activeSubscriptions: (json['activeSubscriptions'] as num?)?.toInt() ?? 0,
      trialSubscriptions: (json['trialSubscriptions'] as num?)?.toInt() ?? 0,
      expiredSubscriptions: (json['expiredSubscriptions'] as num?)?.toInt() ?? 0,
      suspendedSubscriptions: (json['suspendedSubscriptions'] as num?)?.toInt() ?? 0,
      cancelledSubscriptions: (json['cancelledSubscriptions'] as num?)?.toInt() ?? 0,
    );
  }
}

class SuperAdminSubscriptionsData {
  final SubscriptionOverviewSummary summary;
  final List<RestaurantSubscription> subscriptions;

  const SuperAdminSubscriptionsData({
    required this.summary,
    required this.subscriptions,
  });
}
