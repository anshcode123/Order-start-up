import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:scanserve/core/network/dio_client.dart';
import 'package:scanserve/shared/models/subscription.dart';

final subscriptionPlansProvider = FutureProvider<List<SubscriptionPlan>>((ref) async {
  final dio = ref.watch(dioProvider);
  final response = await dio.get('/super-admin/plans');
  final data = response.data as Map<String, dynamic>;
  final list = data['plans'] as List<dynamic>? ?? const [];
  return list
      .map((item) => SubscriptionPlan.fromJson(item as Map<String, dynamic>))
      .toList();
});

final superAdminSubscriptionsProvider = FutureProvider.family<SuperAdminSubscriptionsData, String>((ref, statusFilter) async {
  final dio = ref.watch(dioProvider);
  final queryParams = <String, dynamic>{};
  if (statusFilter.isNotEmpty) {
    queryParams['status'] = statusFilter;
  }
  final response = await dio.get(
    '/super-admin/subscriptions',
    queryParameters: queryParams.isEmpty ? null : queryParams,
  );
  final data = response.data as Map<String, dynamic>;
  final summary = SubscriptionOverviewSummary.fromJson(
    data['summary'] as Map<String, dynamic>? ?? const {},
  );
  final list = (data['subscriptions'] as List<dynamic>? ?? const [])
      .map((item) => RestaurantSubscription.fromJson(item as Map<String, dynamic>))
      .toList();

  return SuperAdminSubscriptionsData(
    summary: summary,
    subscriptions: list,
  );
});

final superAdminRestaurantSubscriptionProvider =
    FutureProvider.family<RestaurantSubscription, String>((ref, restaurantId) async {
  final dio = ref.watch(dioProvider);
  final response = await dio.get('/super-admin/restaurants/$restaurantId/subscription');
  final data = response.data as Map<String, dynamic>;
  return RestaurantSubscription.fromJson(data['subscription'] as Map<String, dynamic>);
});

final restaurantOwnSubscriptionProvider = FutureProvider<RestaurantSubscription>((ref) async {
  final dio = ref.watch(dioProvider);
  final response = await dio.get('/restaurant/subscription');
  final data = response.data as Map<String, dynamic>;
  return RestaurantSubscription.fromJson(data['subscription'] as Map<String, dynamic>);
});
