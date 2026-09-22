import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:scanserve/features/customer_menu/providers/cart_provider.dart';
import 'package:scanserve/features/customer_menu/providers/table_number_provider.dart';

/// Checks whether the current cart belongs to a different restaurant
/// than [restaurantSlug]. If it does, asks the customer to confirm
/// before clearing it. Returns true when it's safe to proceed (no
/// conflict, or the customer chose to clear), false when they cancelled
/// - callers must not add an item or otherwise combine carts unless
/// this returns true.
///
/// Cancelling never clears the cart, so a dismissed dialog leaves the
/// customer free to keep browsing (and the same prompt will reappear if
/// they try to add something) without ever silently mixing restaurants.
Future<bool> ensureCartMatchesRestaurant(
  BuildContext context,
  WidgetRef ref, {
  required String restaurantSlug,
}) async {
  final cartNotifier = ref.read(cartProvider.notifier);

  if (!cartNotifier.wouldConflict(restaurantSlug)) return true;

  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Different restaurant'),
      content: const Text(
        'Your current cart contains items from another restaurant. '
        'Clear cart and continue?',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('Clear Cart & Continue'),
        ),
      ],
    ),
  );

  if (confirmed == true) {
    cartNotifier.clear();
    // A leftover table number belongs to whatever order flow the old
    // cart was mid-way through - drop it along with the cart so the new
    // restaurant's order starts clean.
    ref.read(tableNumberProvider.notifier).state = null;
    return true;
  }

  return false;
}
