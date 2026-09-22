/// Mirrors backend/services/orderService.js's ORDER_STATUSES /
/// ALLOWED_TRANSITIONS. Kept in sync by hand since the two live in
/// separate codebases - the backend is still the actual source of
/// truth/enforcement (Phase 6 spec #14: "Backend must validate status
/// transitions... do not rely only on Flutter UI"). This exists purely
/// so the admin UI can grey out nonsensical buttons instead of letting
/// the customer discover the rule via a rejected request.
const List<String> kOrderStatuses = [
  'PENDING',
  'ACCEPTED',
  'PREPARING',
  'READY',
  'COMPLETED',
  'CANCELLED',
  'REJECTED',
];

const Map<String, List<String>> kAllowedOrderStatusTransitions = {
  'PENDING': ['ACCEPTED', 'REJECTED', 'CANCELLED'],
  'ACCEPTED': ['PREPARING', 'CANCELLED'],
  'PREPARING': ['READY', 'CANCELLED'],
  'READY': ['COMPLETED'],
  'COMPLETED': [],
  'CANCELLED': [],
  'REJECTED': [],
};

List<String> nextStatusesFor(String currentStatus) {
  return kAllowedOrderStatusTransitions[currentStatus] ?? const [];
}
