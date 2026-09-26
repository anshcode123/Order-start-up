import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Selected dining type for the current customer order ('DINE_IN' or 'TAKEAWAY').
final diningTypeProvider = StateProvider<String>((ref) => 'DINE_IN');

/// The customer's table number for the current order flow. Optional for
/// Takeaway or when the restaurant disables `requireTableNumber`.
final tableNumberProvider = StateProvider<String?>((ref) => null);

const int kTableNumberMaxLength = 30;
