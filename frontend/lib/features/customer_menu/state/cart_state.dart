import 'package:scanserve/core/utils/money.dart';
import 'package:scanserve/shared/models/cart_item.dart';

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

  String get formattedTotal => subtotalDisplay;

  bool belongsToAnotherRestaurant(String slug) {
    return items.isNotEmpty && restaurantSlug != null && restaurantSlug != slug;
  }
}
