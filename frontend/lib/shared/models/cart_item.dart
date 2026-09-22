import 'package:scanserve/core/utils/money.dart';

/// One line in the customer's local cart. Nothing here is persisted to
/// the backend in Phase 5 - the cart lives entirely in Flutter state.
class CartItem {
  const CartItem({
    required this.menuItemId,
    required this.name,
    required this.price,
    required this.imageUrl,
    required this.quantity,
  });

  final String menuItemId;
  final String name;
  // Kept as the same "299.00"-style string the backend sends, per the
  // MenuItem model convention - never a double.
  final String price;
  final String? imageUrl;
  final int quantity;

  int get priceCents => priceStringToCents(price);
  int get subtotalCents => priceCents * quantity;
  String get subtotalDisplay => centsToDisplayString(subtotalCents);

  CartItem copyWith({int? quantity}) {
    return CartItem(
      menuItemId: menuItemId,
      name: name,
      price: price,
      imageUrl: imageUrl,
      quantity: quantity ?? this.quantity,
    );
  }
}
