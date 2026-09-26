import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:scanserve/core/network/api_exception.dart';
import 'package:scanserve/core/network/dio_client.dart';
import 'package:scanserve/features/customer_menu/providers/cart_provider.dart';
import 'package:scanserve/features/customer_menu/providers/public_menu_provider.dart';
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

final orderSubmissionProvider =
    StateNotifierProvider.autoDispose<OrderSubmissionNotifier, OrderSubmissionState>((ref) {
  return OrderSubmissionNotifier(ref);
});

class OrderSubmissionNotifier extends StateNotifier<OrderSubmissionState> {
  OrderSubmissionNotifier(this._ref) : super(const OrderSubmissionState());

  final Ref _ref;

  Future<void> submit() async {
    if (state.isSubmitting) return;

    final cart = _ref.read(cartProvider);
    final diningType = _ref.read(diningTypeProvider);
    final tableNumber = _ref.read(tableNumberProvider);

    if (cart.restaurantSlug == null || cart.items.isEmpty) {
      state = const OrderSubmissionState(
        status: OrderSubmissionStatus.failure,
        errorMessage: 'Your cart is empty. Please add items before placing an order.',
      );
      return;
    }

    final menu = _ref.read(publicMenuProvider(cart.restaurantSlug!)).valueOrNull;
    final requireTableNumber = menu?.restaurant.requireTableNumber ?? true;

    if (diningType == 'DINE_IN' &&
        requireTableNumber &&
        (tableNumber == null || tableNumber.trim().isEmpty)) {
      state = const OrderSubmissionState(
        status: OrderSubmissionStatus.failure,
        errorMessage: 'Table number is required for Dine In orders.',
      );
      return;
    }

    state = const OrderSubmissionState(status: OrderSubmissionStatus.submitting);

    try {
      final dio = _ref.read(dioProvider);
      final trimmedTable = tableNumber?.trim() ?? '';

      final response = await dio.post('/public/orders', data: {
        'restaurantSlug': cart.restaurantSlug,
        'diningType': diningType,
        if (diningType == 'DINE_IN' && trimmedTable.isNotEmpty) 'tableNumber': trimmedTable,
        'items': [
          for (final item in cart.items)
            {
              'menuItemId': item.menuItemId,
              if (item.variantId != null && item.variantId!.isNotEmpty)
                'variantId': item.variantId,
              if (item.variantName != null && item.variantName!.isNotEmpty)
                'variantName': item.variantName,
              'quantity': item.quantity,
            },
        ],
      });

      final order = PlacedOrder.fromJson(response.data['data'] as Map<String, dynamic>);

      _ref.read(cartProvider.notifier).clear();
      _ref.read(tableNumberProvider.notifier).state = null;
      _ref.read(diningTypeProvider.notifier).state = 'DINE_IN';

      state = OrderSubmissionState(status: OrderSubmissionStatus.success, order: order);
    } catch (error) {
      state = OrderSubmissionState(
        status: OrderSubmissionStatus.failure,
        errorMessage: apiErrorMessage(error),
      );
    }
  }
}
