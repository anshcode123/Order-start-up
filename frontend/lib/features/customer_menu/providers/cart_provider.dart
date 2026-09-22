import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:scanserve/features/customer_menu/state/cart_state.dart';
import 'package:scanserve/shared/models/cart_item.dart';
import 'package:scanserve/shared/models/menu_item.dart';

/// In-memory cart for the anonymous customer flow (Phase 5). No
/// persistence, no backend calls, no auth token - this is plain
/// Riverpod client state, cleared on page reload by design (the spec
/// allows in-memory-only for this phase).
final cartProvider = StateNotifierProvider<CartNotifier, CartState>((ref) {
  return CartNotifier();
});

class CartNotifier extends StateNotifier<CartState> {
  CartNotifier() : super(const CartState());

  /// Whether adding from [restaurantSlug] would mix restaurants in the
  /// current cart. The menu screen checks this BEFORE calling addItem,
  /// and shows a confirm dialog if true - this notifier never silently
  /// merges carts across restaurants.
  bool wouldConflict(String restaurantSlug) => state.belongsToAnotherRestaurant(restaurantSlug);

  void addItem(MenuItem item, {required String restaurantSlug, required String restaurantName}) {
    final items = [...state.items];
    final index = items.indexWhere((cartItem) => cartItem.menuItemId == item.id);

    if (index >= 0) {
      items[index] = items[index].copyWith(quantity: items[index].quantity + 1);
    } else {
      items.add(CartItem(
        menuItemId: item.id,
        name: item.name,
        price: item.price,
        imageUrl: item.imageUrl,
        quantity: 1,
      ));
    }

    state = CartState(restaurantSlug: restaurantSlug, restaurantName: restaurantName, items: items);
  }

  void incrementItem(String menuItemId) {
    final items = [
      for (final item in state.items)
        item.menuItemId == menuItemId ? item.copyWith(quantity: item.quantity + 1) : item,
    ];
    state = CartState(restaurantSlug: state.restaurantSlug, restaurantName: state.restaurantName, items: items);
  }

  /// Decrementing to zero removes the item entirely (Phase 5 spec).
  void decrementItem(String menuItemId) {
    final items = <CartItem>[];
    for (final item in state.items) {
      if (item.menuItemId != menuItemId) {
        items.add(item);
        continue;
      }
      if (item.quantity > 1) items.add(item.copyWith(quantity: item.quantity - 1));
      // quantity would become 0 - drop it (don't add to the new list).
    }
    state = CartState(restaurantSlug: state.restaurantSlug, restaurantName: state.restaurantName, items: items);
  }

  void removeItem(String menuItemId) {
    final items = state.items.where((item) => item.menuItemId != menuItemId).toList();
    state = CartState(restaurantSlug: state.restaurantSlug, restaurantName: state.restaurantName, items: items);
  }

  void clear() => state = const CartState();
}
