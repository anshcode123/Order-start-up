import 'package:scanserve/core/utils/money.dart';
import 'package:scanserve/shared/models/cart_item.dart';

/// The customer's cart, scoped to a single restaurant at a time
/// (Phase 5 spec: "Cart restaurant isolation" - never combine items
/// from different restaurants). `restaurantSlug`/`restaurantName` are
/// null only when the cart is empty and has never been assigned yet.
class CartState {
  const CartState({
    this.restaurantSlug,
    this.restaurantName,
    this.items = const [],
  });

  final String? restaurantSlug;
  final String? restaurantName;
  final List<CartItem> items;

  bool get isEmpty => items.isEmpty;

  int get totalQuantity => items.fold(0, (sum, item) => sum + item.quantity);

  int get subtotalCents => items.fold(0, (sum, item) => sum + item.subtotalCents);

  String get subtotalDisplay => centsToDisplayString(subtotalCents);

  /// True when the cart already holds items from a different restaurant
  /// than [slug] - the UI shows a confirm-before-clearing dialog when
  /// this is true rather than silently mixing carts.
  bool belongsToAnotherRestaurant(String slug) {
    return items.isNotEmpty && restaurantSlug != null && restaurantSlug != slug;
  }
}
