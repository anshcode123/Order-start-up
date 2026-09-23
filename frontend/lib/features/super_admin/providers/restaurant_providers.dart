import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:scanserve/core/network/dio_client.dart';
import 'package:scanserve/shared/models/restaurant.dart';

/// Search query state for restaurants list screen
final restaurantSearchQueryProvider = StateProvider<String>((ref) => '');

/// GET /api/admin/restaurants - list for the Restaurants screen.
/// Can pass an optional search query string to filter server-side.
final restaurantsListProvider = FutureProvider.autoDispose
    .family<List<Restaurant>, String?>((ref, search) async {
  final dio = ref.watch(dioProvider);
  final uri = (search != null && search.trim().isNotEmpty)
      ? '/admin/restaurants?search=${Uri.encodeComponent(search.trim())}'
      : '/admin/restaurants';
  final response = await dio.get(uri);
  final list =
      (response.data['restaurants'] as List).cast<Map<String, dynamic>>();
  return list.map(Restaurant.fromJson).toList();
});

/// GET /api/admin/restaurants/:id - detail for view/edit/QR screens.
final restaurantDetailProvider = FutureProvider.autoDispose
    .family<RestaurantDetail, String>((ref, id) async {
  final dio = ref.watch(dioProvider);
  final response = await dio.get('/admin/restaurants/$id');
  return RestaurantDetail.fromJson(response.data as Map<String, dynamic>);
});

/// GET /api/super-admin/dashboard/stats - stats + recent restaurants.
final superAdminDashboardProvider =
    FutureProvider.autoDispose<SuperAdminDashboard>((ref) async {
  final dio = ref.watch(dioProvider);
  final response = await dio.get('/super-admin/dashboard/stats');
  return SuperAdminDashboard.fromJson(response.data as Map<String, dynamic>);
});

/// GET /api/super-admin/analytics/orders?period=:period - platform order analytics
final orderAnalyticsProvider = FutureProvider.autoDispose
    .family<OrderAnalytics, String>((ref, period) async {
  final dio = ref.watch(dioProvider);
  final response =
      await dio.get('/super-admin/analytics/orders?period=$period');
  return OrderAnalytics.fromJson(response.data as Map<String, dynamic>);
});

/// GET /api/super-admin/restaurants/:id/stats - usage & order statistics for single restaurant
final restaurantStatsProvider = FutureProvider.autoDispose
    .family<RestaurantUsageStats, String>((ref, id) async {
  final dio = ref.watch(dioProvider);
  final response = await dio.get('/super-admin/restaurants/$id/stats');
  return RestaurantUsageStats.fromJson(response.data as Map<String, dynamic>);
});

/// GET /api/admin/restaurants/:id/qr - QR image + menu URL.
class RestaurantQrData {
  const RestaurantQrData({
    required this.restaurantName,
    required this.menuUrl,
    required this.qrDataUrl,
  });

  final String restaurantName;
  final String menuUrl;
  final String qrDataUrl; // base64 data:image/png;base64,... string

  factory RestaurantQrData.fromJson(Map<String, dynamic> json) {
    return RestaurantQrData(
      restaurantName: json['restaurantName'] as String,
      menuUrl: json['menuUrl'] as String,
      qrDataUrl: json['qrDataUrl'] as String,
    );
  }
}

final restaurantQrProvider = FutureProvider.autoDispose
    .family<RestaurantQrData, String>((ref, id) async {
  final dio = ref.watch(dioProvider);
  final response = await dio.get('/admin/restaurants/$id/qr');
  return RestaurantQrData.fromJson(response.data as Map<String, dynamic>);
});
