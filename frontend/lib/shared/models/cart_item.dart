import 'package:scanserve/core/utils/money.dart';

/// One line in the customer's local cart. Variant-enabled items are
/// distinguished by `menuItemId` + `variantId` / `variantName` so Half and
/// Full of the same dish live as separate cart lines.
class CartItem {
  const CartItem({
    required this.menuItemId,
    required this.name,
    required this.price,
    required this.quantity,
    this.imageUrl,
    this.variantId,
    this.variantName,
  });

  final String menuItemId;
  final String name;
  final String price;
  final String? imageUrl;
  final int quantity;
  final String? variantId;
  final String? variantName;

  int get priceCents => priceStringToCents(price);
  int get subtotalCents => priceCents * quantity;
  String get subtotalDisplay => centsToDisplayString(subtotalCents);

  double get unitPrice => double.tryParse(price) ?? 0.0;
  double get subtotal => unitPrice * quantity;

  String get displayName =>
      (variantName != null && variantName!.isNotEmpty) ? '$name — $variantName' : name;

  bool matchesLine(String targetMenuItemId, {String? targetVariantId, String? targetVariantName}) {
    if (menuItemId != targetMenuItemId) return false;
    if ((variantId ?? '') != (targetVariantId ?? '')) return false;
    if ((variantName ?? '') != (targetVariantName ?? '')) return false;
    return true;
  }

  CartItem copyWith({int? quantity}) {
    return CartItem(
      menuItemId: menuItemId,
      name: name,
      price: price,
      imageUrl: imageUrl,
      quantity: quantity ?? this.quantity,
      variantId: variantId,
      variantName: variantName,
    );
  }
}
