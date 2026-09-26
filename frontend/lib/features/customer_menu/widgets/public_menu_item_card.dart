import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:scanserve/core/theme/app_colors.dart';
import 'package:scanserve/core/theme/app_text_styles.dart';
import 'package:scanserve/features/customer_menu/providers/cart_provider.dart';
import 'package:scanserve/features/customer_menu/widgets/cart_conflict_dialog.dart';
import 'package:scanserve/shared/models/menu_item.dart';

class PublicMenuItemCard extends ConsumerStatefulWidget {
  const PublicMenuItemCard({
    super.key,
    required this.item,
    required this.restaurantSlug,
    required this.restaurantName,
  });

  final MenuItem item;
  final String restaurantSlug;
  final String restaurantName;

  @override
  ConsumerState<PublicMenuItemCard> createState() => _PublicMenuItemCardState();
}

class _PublicMenuItemCardState extends ConsumerState<PublicMenuItemCard> {
  String? _selectedVariantName;

  List<MenuItemVariant> get _availableVariants =>
      widget.item.variants.where((v) => v.isAvailable).toList();

  MenuItemVariant? get _activeVariant {
    if (!widget.item.hasVariants || _availableVariants.isEmpty) return null;
    if (_selectedVariantName != null) {
      final match = _availableVariants.where((v) => v.name == _selectedVariantName);
      if (match.isNotEmpty) return match.first;
    }
    return _availableVariants.first;
  }

  Future<void> _add(BuildContext context, MenuItemVariant? variant) async {
    final canProceed = await ensureCartMatchesRestaurant(
      context,
      ref,
      restaurantSlug: widget.restaurantSlug,
    );
    if (!canProceed) return;
    ref.read(cartProvider.notifier).addItem(
          widget.item,
          restaurantSlug: widget.restaurantSlug,
          restaurantName: widget.restaurantName,
          variant: variant,
        );
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final activeVariant = _activeVariant;

    final quantity = ref.watch(cartProvider.select((cart) {
      final match = cart.items.where(
        (c) => c.matchesLine(
          item.id,
          targetVariantId: activeVariant?.id,
          targetVariantName: activeVariant?.name,
        ),
      );
      return match.isEmpty ? 0 : match.first.quantity;
    }));

    final displayPrice =
        activeVariant != null ? activeVariant.formattedPrice : item.formattedPrice;

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
                          maxLines: item.hasVariants ? 1 : 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    )
                  else
                    const Spacer(),
                  if (item.hasVariants && _availableVariants.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        for (final v in _availableVariants)
                          ChoiceChip(
                            label: Text('${v.name} ${v.formattedPrice}'),
                            selected: activeVariant?.name == v.name,
                            onSelected: (_) => setState(() => _selectedVariantName = v.name),
                            visualDensity: VisualDensity.compact,
                            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 0),
                            selectedColor: AppColors.primaryLight,
                            labelStyle: AppTextStyles.bodySmall.copyWith(
                              fontSize: 11,
                              fontWeight: activeVariant?.name == v.name
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                              color: activeVariant?.name == v.name
                                  ? AppColors.primaryDark
                                  : AppColors.textSecondary,
                            ),
                          ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          displayPrice,
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
                          onPressed: () => _add(context, activeVariant),
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
                          onIncrement: () => ref.read(cartProvider.notifier).incrementItem(
                                item.id,
                                variantId: activeVariant?.id,
                                variantName: activeVariant?.name,
                              ),
                          onDecrement: () => ref.read(cartProvider.notifier).decrementItem(
                                item.id,
                                variantId: activeVariant?.id,
                                variantName: activeVariant?.name,
                              ),
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
