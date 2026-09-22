/// One line of a restaurant-facing order - same snapshot fields as the
/// public-facing PlacedOrderItem, kept as a separate type since this
/// model family is independently scoped to the admin API's response
/// shape (which may end up including more than the public one over
/// time).
class RestaurantOrderItem {
  const RestaurantOrderItem({
    required this.itemName,
    required this.unitPrice,
    required this.quantity,
    required this.subtotal,
  });

  final String itemName;
  final String unitPrice;
  final int quantity;
  final String subtotal;

  factory RestaurantOrderItem.fromJson(Map<String, dynamic> json) {
    return RestaurantOrderItem(
      itemName: json['itemName'] as String,
      unitPrice: json['unitPrice'] as String,
      quantity: json['quantity'] as int,
      subtotal: json['subtotal'] as String,
    );
  }
}

/// An order as the Restaurant Admin sees it - GET /api/restaurant/orders
/// and GET /api/restaurant/orders/:id. Uses the real internal `id` (safe
/// here since access is already gated by auth + req.user.restaurantId,
/// unlike the public customer-facing endpoints).
class RestaurantOrder {
  const RestaurantOrder({
    required this.id,
    required this.tableNumber,
    required this.status,
    required this.items,
    required this.total,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String tableNumber;
  final String status;
  final List<RestaurantOrderItem> items;
  final String total;
  final DateTime createdAt;
  final DateTime updatedAt;

  int get totalQuantity => items.fold(0, (sum, item) => sum + item.quantity);

  factory RestaurantOrder.fromJson(Map<String, dynamic> json) {
    final itemsJson = (json['items'] as List).cast<Map<String, dynamic>>();
    return RestaurantOrder(
      id: json['id'] as String,
      tableNumber: json['tableNumber'] as String,
      status: json['status'] as String,
      items: itemsJson.map(RestaurantOrderItem.fromJson).toList(),
      total: json['total'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );
  }

  /// Parses the leaner shape the "order:new" socket event carries
  /// (Phase 7): {orderId, publicOrderReference, tableNumber, items,
  /// totalAmount, status, createdAt} - field names differ slightly from
  /// the REST response (orderId vs id, totalAmount vs total, no
  /// updatedAt yet), so this gets its own factory rather than
  /// overloading fromJson with two incompatible shapes.
  factory RestaurantOrder.fromNewOrderEvent(Map<String, dynamic> json) {
    final itemsJson = (json['items'] as List).cast<Map<String, dynamic>>();
    final createdAt = DateTime.parse(json['createdAt'] as String);
    return RestaurantOrder(
      id: json['orderId'] as String,
      tableNumber: json['tableNumber'] as String,
      status: json['status'] as String,
      items: itemsJson.map(RestaurantOrderItem.fromJson).toList(),
      total: json['totalAmount'] as String,
      createdAt: createdAt,
      updatedAt: createdAt,
    );
  }

  RestaurantOrder copyWith({String? status, DateTime? updatedAt}) {
    return RestaurantOrder(
      id: id,
      tableNumber: tableNumber,
      status: status ?? this.status,
      items: items,
      total: total,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
