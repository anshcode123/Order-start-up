import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:scanserve/core/network/api_exception.dart';
import 'package:scanserve/core/network/dio_client.dart';
import 'package:scanserve/features/customer_menu/providers/cart_provider.dart';
import 'package:scanserve/features/customer_menu/providers/table_number_provider.dart';
import 'package:scanserve/shared/models/order.dart';

enum OrderSubmissionStatus { idle, submitting, success, failure }

class OrderSubmissionState {
  const OrderSubmissionState({
    this.status = OrderSubmissionStatus.idle,
    this.order,
    this.errorMessage,
  });

  final OrderSubmissionStatus status;
  final PlacedOrder? order;
  final String? errorMessage;

  bool get isSubmitting => status == OrderSubmissionStatus.submitting;
}

/// autoDispose is deliberate: this only needs to live as long as the
/// review screen is on screen. Once the customer is on the success
/// screen (a different route), it's fine for this to reset - the
/// success screen reads the order it needs from its own navigation
/// argument / status fetch, not from this provider.
final orderSubmissionProvider =
    StateNotifierProvider.autoDispose<OrderSubmissionNotifier, OrderSubmissionState>((ref) {
  return OrderSubmissionNotifier(ref);
});

class OrderSubmissionNotifier extends StateNotifier<OrderSubmissionState> {
  OrderSubmissionNotifier(this._ref) : super(const OrderSubmissionState());

  final Ref _ref;

  /// POSTs the current cart + table number to /api/public/orders.
  ///
  /// - Guards against double-submission (a second call while one is
  ///   already in flight is a no-op) - the review screen also disables
  ///   the button while submitting, this is the belt-and-braces backup
  ///   (Phase 6 spec #20).
  /// - The cart and table number are ONLY cleared after the backend
  ///   confirms the order was created - a failed request leaves both
  ///   untouched so the customer can just retry (Phase 6 spec #19).
  Future<void> submit() async {
    if (state.isSubmitting) return;

    final cart = _ref.read(cartProvider);
    final tableNumber = _ref.read(tableNumberProvider);

    if (cart.restaurantSlug == null || cart.items.isEmpty || tableNumber == null) {
      state = const OrderSubmissionState(
        status: OrderSubmissionStatus.failure,
        errorMessage: 'Your cart or table number is missing. Please start again.',
      );
      return;
    }

    state = const OrderSubmissionState(status: OrderSubmissionStatus.submitting);

    try {
      final dio = _ref.read(dioProvider);
      final response = await dio.post('/public/orders', data: {
        'restaurantSlug': cart.restaurantSlug,
        'tableNumber': tableNumber,
        'items': [
          for (final item in cart.items) {'menuItemId': item.menuItemId, 'quantity': item.quantity},
        ],
      });

      final order = PlacedOrder.fromJson(response.data['data'] as Map<String, dynamic>);

      // Confirmed success - now it's safe to clear.
      _ref.read(cartProvider.notifier).clear();
      _ref.read(tableNumberProvider.notifier).state = null;

      state = OrderSubmissionState(status: OrderSubmissionStatus.success, order: order);
    } catch (error) {
      state = OrderSubmissionState(
        status: OrderSubmissionStatus.failure,
        errorMessage: apiErrorMessage(error),
      );
    }
  }
}
