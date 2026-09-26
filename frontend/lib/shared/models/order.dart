/// One line of a placed order, as returned by the public order APIs.
class PlacedOrderItem {
  const PlacedOrderItem({
    required this.itemName,
    required this.unitPrice,
    required this.quantity,
    required this.subtotal,
    this.variantId,
    this.variantName,
  });

  final String itemName;
  final String unitPrice;
  final int quantity;
  final String subtotal;
  final String? variantId;
  final String? variantName;

  String get displayName =>
      (variantName != null && variantName!.isNotEmpty) ? '$itemName ($variantName)' : itemName;

  factory PlacedOrderItem.fromJson(Map<String, dynamic> json) {
    return PlacedOrderItem(
      itemName: json['itemName'] as String,
      unitPrice: json['unitPrice'].toString(),
      quantity: (json['quantity'] as num).toInt(),
      subtotal: json['subtotal'].toString(),
      variantId: json['variantId'] as String?,
      variantName: json['variantName'] as String?,
    );
  }
}

/// A placed order as the customer sees it - from POST /api/public/orders
/// or GET /api/public/orders/:orderRef/status.
class PlacedOrder {
  const PlacedOrder({
    required this.orderId,
    required this.orderNumber,
    required this.restaurantName,
    required this.diningType,
    required this.tableNumber,
    required this.status,
    required this.items,
    required this.total,
    required this.createdAt,
  });

  final String orderId;
  final String orderNumber;
  final String? restaurantName;
  final String diningType;
  final String? tableNumber;
  final String status;
  final List<PlacedOrderItem> items;
  final String total;
  final DateTime createdAt;

  String get diningLabel => diningType == 'TAKEAWAY' ? 'Takeaway' : 'Dine In';

  bool get hasTableNumber => tableNumber != null && tableNumber!.trim().isNotEmpty;

  String get diningSummary => hasTableNumber ? '$diningLabel · Table $tableNumber' : diningLabel;

  factory PlacedOrder.fromJson(Map<String, dynamic> json) {
    final itemsJson = (json['items'] as List).cast<Map<String, dynamic>>();
    return PlacedOrder(
      orderId: json['orderId'] as String,
      orderNumber: json['orderNumber'] as String,
      restaurantName: json['restaurantName'] as String?,
      diningType: (json['diningType'] as String?) ?? 'DINE_IN',
      tableNumber: json['tableNumber'] as String?,
      status: json['status'] as String,
      items: itemsJson.map(PlacedOrderItem.fromJson).toList(),
      total: json['total'].toString(),
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }
}
