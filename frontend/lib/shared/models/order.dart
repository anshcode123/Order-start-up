/// One line of a placed order, as returned by the public order APIs.
/// Distinct from CartItem: this is a server-confirmed snapshot (name and
/// price as the backend actually charged), not client-side cart state.
class PlacedOrderItem {
  const PlacedOrderItem({
    required this.itemName,
    required this.unitPrice,
    required this.quantity,
    required this.subtotal,
  });

  final String itemName;
  final String unitPrice;
  final int quantity;
  final String subtotal;

  factory PlacedOrderItem.fromJson(Map<String, dynamic> json) {
    return PlacedOrderItem(
      itemName: json['itemName'] as String,
      unitPrice: json['unitPrice'] as String,
      quantity: json['quantity'] as int,
      subtotal: json['subtotal'] as String,
    );
  }
}

/// A placed order as the customer sees it - from POST /api/public/orders
/// or GET /api/public/orders/:orderRef/status. `orderId` here is the
/// backend's securely-random public token, never the internal database
/// id (see backend/services/orderService.js).
class PlacedOrder {
  const PlacedOrder({
    required this.orderId,
    required this.orderNumber,
    required this.restaurantName,
    required this.tableNumber,
    required this.status,
    required this.items,
    required this.total,
    required this.createdAt,
  });

  final String orderId;
  final String orderNumber;
  final String? restaurantName;
  final String tableNumber;
  final String status;
  final List<PlacedOrderItem> items;
  final String total;
  final DateTime createdAt;

  factory PlacedOrder.fromJson(Map<String, dynamic> json) {
    final itemsJson = (json['items'] as List).cast<Map<String, dynamic>>();
    return PlacedOrder(
      orderId: json['orderId'] as String,
      orderNumber: json['orderNumber'] as String,
      restaurantName: json['restaurantName'] as String?,
      tableNumber: json['tableNumber'] as String,
      status: json['status'] as String,
      items: itemsJson.map(PlacedOrderItem.fromJson).toList(),
      total: json['total'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }
}
