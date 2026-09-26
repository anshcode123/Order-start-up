import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:scanserve/core/constants/app_routes.dart';
import 'package:scanserve/core/theme/app_colors.dart';
import 'package:scanserve/core/theme/app_text_styles.dart';
import 'package:scanserve/core/utils/responsive.dart';
import 'package:scanserve/features/customer_menu/providers/cart_provider.dart';
import 'package:scanserve/features/customer_menu/providers/public_menu_provider.dart';
import 'package:scanserve/features/customer_menu/providers/table_number_provider.dart';
import 'package:scanserve/shared/models/cart_item.dart';
import 'package:scanserve/shared/widgets/app_button.dart';

class CartScreen extends ConsumerStatefulWidget {
  const CartScreen({super.key});

  @override
  ConsumerState<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends ConsumerState<CartScreen> {
  late final TextEditingController _tableController;
  String? _tableError;

  @override
  void initState() {
    super.initState();
    _tableController = TextEditingController(text: ref.read(tableNumberProvider) ?? '');
  }

  @override
  void dispose() {
    _tableController.dispose();
    super.dispose();
  }

  void _proceed(bool requireTableNumber) {
    final diningType = ref.read(diningTypeProvider);
    final trimmed = _tableController.text.trim();

    if (diningType == 'DINE_IN') {
      if (requireTableNumber && trimmed.isEmpty) {
        setState(() => _tableError = 'Table number is required for Dine In orders');
        return;
      }
      if (trimmed.length > kTableNumberMaxLength) {
        setState(
          () => _tableError = 'Table number must be $kTableNumberMaxLength characters or fewer',
        );
        return;
      }
      setState(() => _tableError = null);
      ref.read(tableNumberProvider.notifier).state = trimmed.isNotEmpty ? trimmed : null;
    } else {
      setState(() => _tableError = null);
      ref.read(tableNumberProvider.notifier).state = null;
    }

    context.push(AppRoutes.orderReview);
  }

  @override
  Widget build(BuildContext context) {
    final cart = ref.watch(cartProvider);
    final diningType = ref.watch(diningTypeProvider);
    final menuAsync = cart.restaurantSlug != null
        ? ref.watch(publicMenuProvider(cart.restaurantSlug!))
        : null;
    final requireTableNumber = menuAsync?.valueOrNull?.restaurant.requireTableNumber ?? true;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        title: const Text('Your Cart'),
      ),
      body: cart.isEmpty
          ? const _EmptyCart()
          : SingleChildScrollView(
              padding: EdgeInsets.all(Responsive.pagePadding(context)),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 640),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (cart.restaurantName != null) ...[
                        Text(cart.restaurantName!, style: AppTextStyles.title),
                        const SizedBox(height: 16),
                      ],
                      for (final item in cart.items) _CartLineCard(item: item),
                      const SizedBox(height: 20),

                      // Dining Type Selection
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Dining Preference', style: AppTextStyles.title),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: _DiningOptionTile(
                                    label: 'Dine In',
                                    icon: Icons.table_bar_outlined,
                                    selected: diningType == 'DINE_IN',
                                    onTap: () =>
                                        ref.read(diningTypeProvider.notifier).state = 'DINE_IN',
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: _DiningOptionTile(
                                    label: 'Takeaway',
                                    icon: Icons.takeout_dining_outlined,
                                    selected: diningType == 'TAKEAWAY',
                                    onTap: () {
                                      ref.read(diningTypeProvider.notifier).state = 'TAKEAWAY';
                                      setState(() => _tableError = null);
                                    },
                                  ),
                                ),
                              ],
                            ),
                            if (diningType == 'DINE_IN') ...[
                              const SizedBox(height: 16),
                              Text(
                                requireTableNumber ? 'Table Number *' : 'Table Number (optional)',
                                style: AppTextStyles.bodySmall.copyWith(
                                  color: AppColors.textPrimary,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 6),
                              TextFormField(
                                controller: _tableController,
                                decoration: const InputDecoration(
                                  hintText: 'e.g. 4, A12, VIP-1',
                                ),
                                onChanged: (value) {
                                  if (_tableError != null) {
                                    setState(() => _tableError = null);
                                  }
                                  final t = value.trim();
                                  ref.read(tableNumberProvider.notifier).state =
                                      t.isEmpty ? null : t;
                                },
                              ),
                              if (_tableError != null) ...[
                                const SizedBox(height: 6),
                                Text(
                                  _tableError!,
                                  style: AppTextStyles.bodySmall.copyWith(color: AppColors.error),
                                ),
                              ],
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),

                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                const Text('Total', style: AppTextStyles.title),
                                const Spacer(),
                                Text(
                                  cart.subtotalDisplay,
                                  style: AppTextStyles.displayMedium.copyWith(
                                    fontSize: 22,
                                    color: AppColors.primaryDark,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            AppPrimaryButton(
                              label: 'Proceed to Order',
                              expand: true,
                              onPressed: () => _proceed(requireTableNumber),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
    );
  }
}

class _DiningOptionTile extends StatelessWidget {
  const _DiningOptionTile({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
        decoration: BoxDecoration(
          color: selected ? AppColors.primaryLight : AppColors.background,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.border,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 18,
              color: selected ? AppColors.primaryDark : AppColors.textSecondary,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: AppTextStyles.bodySmall.copyWith(
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                color: selected ? AppColors.primaryDark : AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CartLineCard extends ConsumerWidget {
  const _CartLineCard({required this.item});

  final CartItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(cartProvider.notifier);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.displayName,
                  style: AppTextStyles.title.copyWith(fontSize: 15),
                ),
                const SizedBox(height: 4),
                Text(
                  '₹${item.unitPrice.toStringAsFixed(2)} each',
                  style: AppTextStyles.bodySmall,
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.remove_circle_outline, size: 20),
            onPressed: () => notifier.decrementItem(
              item.menuItemId,
              variantId: item.variantId,
              variantName: item.variantName,
            ),
          ),
          Text('${item.quantity}', style: AppTextStyles.title.copyWith(fontSize: 15)),
          IconButton(
            icon: const Icon(Icons.add_circle_outline, size: 20),
            onPressed: () => notifier.incrementItem(
              item.menuItemId,
              variantId: item.variantId,
              variantName: item.variantName,
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 72,
            child: Text(
              item.subtotalDisplay,
              textAlign: TextAlign.right,
              style: AppTextStyles.title.copyWith(fontSize: 15),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, size: 20, color: AppColors.error),
            tooltip: 'Remove',
            onPressed: () => notifier.removeItem(
              item.menuItemId,
              variantId: item.variantId,
              variantName: item.variantName,
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyCart extends StatelessWidget {
  const _EmptyCart();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.shopping_bag_outlined, size: 52, color: AppColors.textMuted),
            const SizedBox(height: 16),
            const Text('Your cart is empty', style: AppTextStyles.title),
            const SizedBox(height: 6),
            Text(
              'Browse the menu and add something delicious.',
              style: AppTextStyles.bodySmall.copyWith(color: AppColors.textMuted),
            ),
          ],
        ),
      ),
    );
  }
}
