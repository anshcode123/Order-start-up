import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:scanserve/core/network/dio_client.dart';
import 'package:scanserve/shared/models/restaurant_order.dart';

/// The currently-selected status filter on the Orders screen. Null
/// means "all statuses". Applied CLIENT-SIDE over restaurantOrdersProvider's
/// list (same pattern as the Phase 4 Menu screen's category/availability
/// filters) - this is what lets a "order:new" socket event just prepend
/// to one single in-memory list regardless of which filter tab is
/// active, rather than needing a separate fetch per filter value.
final orderStatusFilterProvider = StateProvider<String?>((ref) => null);

/// Set to a fresh RestaurantOrder every time an "order:new" socket event
/// arrives (see restaurant_order_socket_provider.dart), so
/// RestaurantAdminScaffold can `ref.listen` here and show an in-app
/// "New order received" notification (Phase 7 spec #21) regardless of
/// which /dashboard/* tab is currently open - not just when the Orders
/// screen itself happens to be visible. Every event is a new object
/// instance, so Riverpod's listen fires on each one even if two orders
/// happened to have identical field values.
final newOrderEventProvider = StateProvider<RestaurantOrder?>((ref) => null);

/// Restaurant Admin's order list - GET /api/restaurant/orders on load,
/// then patched in place by Phase 7 socket events (see
/// restaurant_order_socket_provider.dart) rather than re-fetched. REST
/// remains the source of truth: call refresh() any time full
/// resynchronization is needed (pull-to-refresh, reconnect after a
/// dropped socket).
class RestaurantOrdersNotifier extends StateNotifier<AsyncValue<List<RestaurantOrder>>> {
  RestaurantOrdersNotifier(this._ref) : super(const AsyncValue.loading()) {
    refresh();
  }

  final Ref _ref;

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    try {
      final dio = _ref.read(dioProvider);
      final response = await dio.get('/restaurant/orders');
      final list = (response.data['data'] as List).cast<Map<String, dynamic>>();
      state = AsyncValue.data(list.map(RestaurantOrder.fromJson).toList());
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
    }
  }

  /// Adds a new order from an "order:new" socket event. Deduplicates by
  /// id (Phase 7 spec #13) - if a REST refresh already picked this order
  /// up (e.g. a reconnect raced with the event), this is a no-op rather
  /// than a second entry.
  void upsertFromNewOrderEvent(Map<String, dynamic> eventJson) {
    final order = RestaurantOrder.fromNewOrderEvent(eventJson);
    final current = state.valueOrNull;
    if (current == null) return; // initial load not finished yet; refresh() will include it
    if (current.any((existing) => existing.id == order.id)) return;
    state = AsyncValue.data([order, ...current]);
  }

  /// Patches just the status (+ updatedAt) of an existing order in
  /// place from an "order:status_updated" socket event - never appends
  /// a new row for a status change, and does nothing if the order isn't
  /// in the currently-loaded list (e.g. it belongs to a page not yet
  /// fetched - refresh() will pick up the correct state next time).
  void patchStatusFromEvent(Map<String, dynamic> eventJson) {
    final orderId = eventJson['orderId'] as String?;
    final status = eventJson['status'] as String?;
    final updatedAtRaw = eventJson['updatedAt'] as String?;
    if (orderId == null || status == null) return;

    final current = state.valueOrNull;
    if (current == null) return;

    final updatedAt = updatedAtRaw != null ? DateTime.parse(updatedAtRaw) : DateTime.now();
    state = AsyncValue.data([
      for (final order in current)
        if (order.id == orderId) order.copyWith(status: status, updatedAt: updatedAt) else order,
    ]);
  }
}

final restaurantOrdersProvider =
    StateNotifierProvider.autoDispose<RestaurantOrdersNotifier, AsyncValue<List<RestaurantOrder>>>((ref) {
  return RestaurantOrdersNotifier(ref);
});

/// GET /api/restaurant/orders/:id
final restaurantOrderDetailProvider =
    FutureProvider.autoDispose.family<RestaurantOrder, String>((ref, id) async {
  final dio = ref.watch(dioProvider);
  final response = await dio.get('/restaurant/orders/$id');
  return RestaurantOrder.fromJson(response.data['data'] as Map<String, dynamic>);
});
