/// Mirrors backend/services/orderService.js's ORDER_STATUSES /
/// ALLOWED_TRANSITIONS. Phase 13 removes COMPLETED so READY is the
/// final happy-path order status.
const List<String> kOrderStatuses = [
  'PENDING',
  'ACCEPTED',
  'PREPARING',
  'READY',
  'CANCELLED',
  'REJECTED',
];

const Map<String, List<String>> kAllowedOrderStatusTransitions = {
  'PENDING': ['ACCEPTED', 'REJECTED', 'CANCELLED'],
  'ACCEPTED': ['PREPARING', 'CANCELLED'],
  'PREPARING': ['READY', 'CANCELLED'],
  'READY': [],
  'CANCELLED': [],
  'REJECTED': [],
};

List<String> nextStatusesFor(String currentStatus) {
  return kAllowedOrderStatusTransitions[currentStatus] ?? const [];
}
