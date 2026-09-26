import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:scanserve/features/customer_menu/providers/cart_provider.dart';
import 'package:scanserve/features/customer_menu/providers/table_number_provider.dart';

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
    ref.read(tableNumberProvider.notifier).state = null;
    ref.read(diningTypeProvider.notifier).state = 'DINE_IN';
    return true;
  }

  return false;
}
