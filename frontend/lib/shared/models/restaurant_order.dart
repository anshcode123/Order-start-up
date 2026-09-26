class RestaurantOrderItem {
  const RestaurantOrderItem({
    required this.id,
    required this.menuItemId,
    required this.itemName,
    required this.unitPrice,
    required this.quantity,
    required this.subtotal,
    this.variantId,
    this.variantName,
  });

  final String? id;
  final String? menuItemId;
  final String itemName;
  final String unitPrice;
  final int quantity;
  final String subtotal;
  final String? variantId;
  final String? variantName;

  String get displayName =>
      (variantName != null && variantName!.isNotEmpty) ? '$itemName ($variantName)' : itemName;

  factory RestaurantOrderItem.fromJson(Map<String, dynamic> json) {
    return RestaurantOrderItem(
      id: json['id'] as String?,
      menuItemId: json['menuItemId'] as String?,
      itemName: json['itemName'] as String,
      unitPrice: json['unitPrice'].toString(),
      quantity: (json['quantity'] as num).toInt(),
      subtotal: json['subtotal'].toString(),
      variantId: json['variantId'] as String?,
      variantName: json['variantName'] as String?,
    );
  }
}

/// An order as the Restaurant Admin sees it (from /api/restaurant/orders
/// or a live Socket.IO event).
class RestaurantOrder {
  const RestaurantOrder({
    required this.id,
    required this.diningType,
    required this.tableNumber,
    required this.status,
    required this.items,
    required this.total,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String diningType;
  final String? tableNumber;
  final String status;
  final List<RestaurantOrderItem> items;
  final String total;
  final DateTime createdAt;
  final DateTime updatedAt;

  int get totalQuantity => items.fold(0, (sum, line) => sum + line.quantity);

  String get diningLabel => diningType == 'TAKEAWAY' ? 'Takeaway' : 'Dine In';

  bool get hasTableNumber => tableNumber != null && tableNumber!.trim().isNotEmpty;

  String get diningSummary => hasTableNumber ? '$diningLabel · Table $tableNumber' : diningLabel;

  factory RestaurantOrder.fromJson(Map<String, dynamic> json) {
    final itemsJson = (json['items'] as List).cast<Map<String, dynamic>>();
    final createdAt = DateTime.parse(json['createdAt'] as String);
    return RestaurantOrder(
      id: json['id'] as String,
      diningType: (json['diningType'] as String?) ?? 'DINE_IN',
      tableNumber: json['tableNumber'] as String?,
      status: json['status'] as String,
      items: itemsJson.map(RestaurantOrderItem.fromJson).toList(),
      total: (json['total'] ?? json['totalAmount']).toString(),
      createdAt: createdAt,
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'] as String)
          : createdAt,
    );
  }

  /// Parses the "order:new" socket event payload.
  factory RestaurantOrder.fromNewOrderEvent(Map<String, dynamic> json) {
    final itemsJson = (json['items'] as List).cast<Map<String, dynamic>>();
    final createdAt = DateTime.parse(json['createdAt'] as String);
    return RestaurantOrder(
      id: json['orderId'] as String,
      diningType: (json['diningType'] as String?) ?? 'DINE_IN',
      tableNumber: json['tableNumber'] as String?,
      status: json['status'] as String,
      items: itemsJson.map(RestaurantOrderItem.fromJson).toList(),
      total: json['totalAmount'].toString(),
      createdAt: createdAt,
      updatedAt: createdAt,
    );
  }

  RestaurantOrder copyWith({String? status, DateTime? updatedAt}) {
    return RestaurantOrder(
      id: id,
      diningType: diningType,
      tableNumber: tableNumber,
      status: status ?? this.status,
      items: items,
      total: total,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
