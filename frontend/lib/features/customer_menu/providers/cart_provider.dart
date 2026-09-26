import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:scanserve/features/customer_menu/state/cart_state.dart';
import 'package:scanserve/shared/models/cart_item.dart';
import 'package:scanserve/shared/models/menu_item.dart';

export 'package:scanserve/features/customer_menu/state/cart_state.dart';

class CartNotifier extends StateNotifier<CartState> {
  CartNotifier() : super(const CartState());

  bool wouldConflict(String restaurantSlug) {
    return state.belongsToAnotherRestaurant(restaurantSlug);
  }

  void addItem(
    MenuItem item, {
    required String restaurantSlug,
    required String restaurantName,
    MenuItemVariant? variant,
  }) {
    final priceStr = variant != null ? variant.price : item.price;
    final variantId = variant?.id;
    final variantName = variant?.name;

    final existingIndex = state.items.indexWhere(
      (c) => c.matchesLine(
        item.id,
        targetVariantId: variantId,
        targetVariantName: variantName,
      ),
    );

    final List<CartItem> updated;
    if (existingIndex == -1) {
      updated = [
        ...state.items,
        CartItem(
          menuItemId: item.id,
          name: item.name,
          price: priceStr,
          quantity: 1,
          imageUrl: item.imageUrl,
          variantId: variantId,
          variantName: variantName,
        ),
      ];
    } else {
      updated = [
        for (int i = 0; i < state.items.length; i++)
          if (i == existingIndex)
            state.items[i].copyWith(quantity: state.items[i].quantity + 1)
          else
            state.items[i],
      ];
    }

    state = CartState(
      restaurantSlug: restaurantSlug,
      restaurantName: restaurantName,
      items: updated,
    );
  }

  void incrementItem(String menuItemId, {String? variantId, String? variantName}) {
    state = CartState(
      restaurantSlug: state.restaurantSlug,
      restaurantName: state.restaurantName,
      items: [
        for (final item in state.items)
          if (item.matchesLine(menuItemId, targetVariantId: variantId, targetVariantName: variantName))
            item.copyWith(quantity: item.quantity + 1)
          else
            item,
      ],
    );
  }

  void decrementItem(String menuItemId, {String? variantId, String? variantName}) {
    final updated = <CartItem>[];
    for (final item in state.items) {
      if (!item.matchesLine(menuItemId, targetVariantId: variantId, targetVariantName: variantName)) {
        updated.add(item);
      } else if (item.quantity > 1) {
        updated.add(item.copyWith(quantity: item.quantity - 1));
      }
    }

    if (updated.isEmpty) {
      state = const CartState();
    } else {
      state = CartState(
        restaurantSlug: state.restaurantSlug,
        restaurantName: state.restaurantName,
        items: updated,
      );
    }
  }

  void removeItem(String menuItemId, {String? variantId, String? variantName}) {
    final updated = state.items
        .where(
          (item) => !item.matchesLine(
            menuItemId,
            targetVariantId: variantId,
            targetVariantName: variantName,
          ),
        )
        .toList();
    if (updated.isEmpty) {
      state = const CartState();
    } else {
      state = CartState(
        restaurantSlug: state.restaurantSlug,
        restaurantName: state.restaurantName,
        items: updated,
      );
    }
  }

  void clear() {
    state = const CartState();
  }
}

final cartProvider = StateNotifierProvider<CartNotifier, CartState>((ref) {
  return CartNotifier();
});
