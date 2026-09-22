import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The customer's table number for the current order flow. A plain
/// String by design (Phase 5 spec: "Table number must be a STRING" -
/// "A12", "12B", "VIP-1" must all be valid). Reset to null whenever the
/// cart is cleared for a restaurant switch (see cart_conflict_dialog.dart)
/// so a leftover table number never carries over to a different order.
final tableNumberProvider = StateProvider<String?>((ref) => null);

const int kTableNumberMaxLength = 30;
