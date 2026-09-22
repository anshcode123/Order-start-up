import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:scanserve/core/network/dio_client.dart';
import 'package:scanserve/shared/models/order.dart';

/// Customer's order status - GET /api/public/orders/:orderRef/status on
/// load, then replaced wholesale by Phase 7 "order:status_updated"
/// socket events (see customer_order_socket_provider.dart). The socket
/// payload is deliberately shaped identically to this REST response
/// (see backend/controllers/orderController.js), so a live update is
/// just PlacedOrder.fromJson on the event data - no separate merge
/// logic needed. REST remains the source of truth: refresh() re-syncs
/// any time that's needed (e.g. right after a (re)connect).
class PlacedOrderNotifier extends StateNotifier<AsyncValue<PlacedOrder>> {
  PlacedOrderNotifier(this._ref, this.orderRef) : super(const AsyncValue.loading()) {
    refresh();
  }

  final Ref _ref;
  final String orderRef;

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    try {
      final dio = _ref.read(dioProvider);
      final response = await dio.get('/public/orders/$orderRef/status');
      state = AsyncValue.data(PlacedOrder.fromJson(response.data['data'] as Map<String, dynamic>));
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
    }
  }

  /// Applies a live "order:status_updated" event. Defensively checks the
  /// event is actually for this order before replacing state - the
  /// socket only ever puts this client in its own order:{token} room,
  /// but this keeps the identity check explicit rather than assumed.
  void applyRealtimeUpdate(Map<String, dynamic> eventJson) {
    final incoming = PlacedOrder.fromJson(eventJson);
    if (incoming.orderId != orderRef) return;
    state = AsyncValue.data(incoming);
  }
}

final publicOrderStatusProvider = StateNotifierProvider.autoDispose
    .family<PlacedOrderNotifier, AsyncValue<PlacedOrder>, String>((ref, orderRef) {
  return PlacedOrderNotifier(ref, orderRef);
});
