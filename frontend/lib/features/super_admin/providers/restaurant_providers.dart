import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:scanserve/core/network/dio_client.dart';
import 'package:scanserve/shared/models/restaurant.dart';

/// GET /api/admin/restaurants - list for the Restaurants screen.
/// autoDispose + ref.invalidate(restaurantsListProvider) after a
/// create/edit/status-change is how the list stays fresh.
final restaurantsListProvider = FutureProvider.autoDispose<List<Restaurant>>((ref) async {
  final dio = ref.watch(dioProvider);
  final response = await dio.get('/admin/restaurants');
  final list = (response.data['restaurants'] as List).cast<Map<String, dynamic>>();
  return list.map(Restaurant.fromJson).toList();
});

/// GET /api/admin/restaurants/:id - detail for view/edit/QR screens.
final restaurantDetailProvider =
    FutureProvider.autoDispose.family<RestaurantDetail, String>((ref, id) async {
  final dio = ref.watch(dioProvider);
  final response = await dio.get('/admin/restaurants/$id');
  return RestaurantDetail.fromJson(response.data as Map<String, dynamic>);
});

/// GET /api/admin/dashboard - stats + recent restaurants.
final superAdminDashboardProvider = FutureProvider.autoDispose<SuperAdminDashboard>((ref) async {
  final dio = ref.watch(dioProvider);
  final response = await dio.get('/admin/dashboard');
  return SuperAdminDashboard.fromJson(response.data as Map<String, dynamic>);
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

final restaurantQrProvider =
    FutureProvider.autoDispose.family<RestaurantQrData, String>((ref, id) async {
  final dio = ref.watch(dioProvider);
  final response = await dio.get('/admin/restaurants/$id/qr');
  return RestaurantQrData.fromJson(response.data as Map<String, dynamic>);
});
