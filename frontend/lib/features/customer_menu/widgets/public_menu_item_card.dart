import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:scanserve/core/theme/app_colors.dart';
import 'package:scanserve/core/theme/app_text_styles.dart';
import 'package:scanserve/features/customer_menu/providers/cart_provider.dart';
import 'package:scanserve/features/customer_menu/widgets/cart_conflict_dialog.dart';
import 'package:scanserve/shared/models/menu_item.dart';

class PublicMenuItemCard extends ConsumerWidget {
  const PublicMenuItemCard({
    super.key,
    required this.item,
    required this.restaurantSlug,
    required this.restaurantName,
  });

  final MenuItem item;
  final String restaurantSlug;
  final String restaurantName;

  Future<void> _add(BuildContext context, WidgetRef ref) async {
    final canProceed = await ensureCartMatchesRestaurant(context, ref, restaurantSlug: restaurantSlug);
    if (!canProceed) return;
    ref.read(cartProvider.notifier).addItem(
          item,
          restaurantSlug: restaurantSlug,
          restaurantName: restaurantName,
        );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final quantity = ref.watch(cartProvider.select((cart) {
      final match = cart.items.where((c) => c.menuItemId == item.id);
      return match.isEmpty ? 0 : match.first.quantity;
    }));

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AspectRatio(
            aspectRatio: 4 / 3,
            child: item.imageUrl != null
                ? Image.network(
                    item.imageUrl!,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => _placeholder(),
                  )
                : _placeholder(),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.title.copyWith(fontSize: 15),
                  ),
                  if (item.description.isNotEmpty)
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          item.description,
                          style: AppTextStyles.bodySmall,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    )
                  else
                    const Spacer(),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          item.formattedPrice,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.title.copyWith(
                            color: AppColors.primaryDark,
                            fontSize: 15,
                          ),
                        ),
                      ),
                      if (quantity == 0)
                        FilledButton(
                          onPressed: () => _add(context, ref),
                          style: FilledButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                            minimumSize: const Size(0, 32),
                          ),
                          child: const Text('Add'),
                        )
                      else
                        _QuantityStepper(
                          quantity: quantity,
                          onIncrement: () => ref.read(cartProvider.notifier).incrementItem(item.id),
                          onDecrement: () => ref.read(cartProvider.notifier).decrementItem(item.id),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _placeholder() {
    return Container(
      color: AppColors.primaryLight,
      child: const Center(
        child: Icon(Icons.restaurant_rounded, color: AppColors.primaryDark, size: 36),
      ),
    );
  }
}

class _QuantityStepper extends StatelessWidget {
  const _QuantityStepper({
    required this.quantity,
    required this.onIncrement,
    required this.onDecrement,
  });

  final int quantity;
  final VoidCallback onIncrement;
  final VoidCallback onDecrement;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.primaryLight,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _stepButton(Icons.remove, onDecrement),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Text('$quantity', style: AppTextStyles.title.copyWith(fontSize: 14)),
          ),
          _stepButton(Icons.add, onIncrement),
        ],
      ),
    );
  }

  Widget _stepButton(IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.all(6),
        child: Icon(icon, size: 16, color: AppColors.primaryDark),
      ),
    );
  }
}
