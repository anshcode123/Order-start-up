import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:scanserve/core/network/dio_client.dart';
import 'package:scanserve/shared/models/category.dart';
import 'package:scanserve/shared/models/menu_item.dart';

/// GET /api/restaurant/categories - the caller's own restaurant only
/// (enforced server-side via req.user.restaurantId).
final categoriesProvider =
    FutureProvider.autoDispose<List<Category>>((ref) async {
  final dio = ref.watch(dioProvider);
  final response = await dio.get('/restaurant/categories');
  final list = (response.data['data'] as List).cast<Map<String, dynamic>>();
  return list.map(Category.fromJson).toList();
});

/// GET /api/restaurant/menu-items - fetched unfiltered; the Menu screen
/// applies category/availability/search filters client-side over this
/// list (Phase 4 spec #17 - "keep the UI simple").
final menuItemsProvider =
    FutureProvider.autoDispose<List<MenuItem>>((ref) async {
  final dio = ref.watch(dioProvider);
  final response = await dio.get('/restaurant/menu-items');
  final list = (response.data['data'] as List).cast<Map<String, dynamic>>();
  return list.map(MenuItem.fromJson).toList();
});

/// GET /api/restaurant/menu-items/:id - used to prefill the edit form.
final menuItemProvider =
    FutureProvider.autoDispose.family<MenuItem, String>((ref, id) async {
  final dio = ref.watch(dioProvider);
  final response = await dio.get('/restaurant/menu-items/$id');
  return MenuItem.fromJson(response.data['data'] as Map<String, dynamic>);
});

/// GET /api/restaurant/dashboard - real counts for the Restaurant Admin
/// dashboard (Phase 4 spec #19).
class RestaurantAdminStats {
  const RestaurantAdminStats({
    required this.totalCategories,
    required this.totalMenuItems,
    required this.availableItems,
    required this.unavailableItems,
  });

  final int totalCategories;
  final int totalMenuItems;
  final int availableItems;
  final int unavailableItems;

  factory RestaurantAdminStats.fromJson(Map<String, dynamic> json) {
    return RestaurantAdminStats(
      totalCategories: json['totalCategories'] as int,
      totalMenuItems: json['totalMenuItems'] as int,
      availableItems: json['availableItems'] as int,
      unavailableItems: json['unavailableItems'] as int,
    );
  }
}

final restaurantAdminStatsProvider =
    FutureProvider.autoDispose<RestaurantAdminStats>((ref) async {
  final dio = ref.watch(dioProvider);
  final response = await dio.get('/restaurant/dashboard');
  return RestaurantAdminStats.fromJson(
      response.data['data'] as Map<String, dynamic>);
});

/// GET /api/restaurant/qr - the Restaurant Admin's own QR (self-service
/// version of the Super Admin's per-restaurant QR view).
class OwnRestaurantQr {
  const OwnRestaurantQr({
    required this.restaurantName,
    required this.menuUrl,
    required this.qrDataUrl,
  });

  final String restaurantName;
  final String menuUrl;
  final String qrDataUrl;

  factory OwnRestaurantQr.fromJson(Map<String, dynamic> json) {
    return OwnRestaurantQr(
      restaurantName: json['restaurantName'] as String,
      menuUrl: json['menuUrl'] as String,
      qrDataUrl: json['qrDataUrl'] as String,
    );
  }
}

final ownRestaurantQrProvider =
    FutureProvider.autoDispose<OwnRestaurantQr>((ref) async {
  final dio = ref.watch(dioProvider);
  final response = await dio.get('/restaurant/qr');
  return OwnRestaurantQr.fromJson(
      response.data['data'] as Map<String, dynamic>);
});

/// GET /api/restaurant/settings - the caller's own restaurant settings
final restaurantSettingsProvider =
    FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  final dio = ref.watch(dioProvider);
  final response = await dio.get('/restaurant/settings');
  return response.data['data'] as Map<String, dynamic>;
});
