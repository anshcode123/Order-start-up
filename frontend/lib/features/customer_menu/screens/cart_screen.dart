import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:scanserve/core/constants/app_routes.dart';
import 'package:scanserve/core/theme/app_colors.dart';
import 'package:scanserve/core/theme/app_text_styles.dart';
import 'package:scanserve/core/utils/responsive.dart';
import 'package:scanserve/features/customer_menu/providers/cart_provider.dart';
import 'package:scanserve/shared/models/cart_item.dart';
import 'package:scanserve/shared/widgets/app_button.dart';

/// /cart - shows the customer's local cart. No auth, no backend call:
/// everything here reads/writes cartProvider directly (Phase 5 spec).
class CartScreen extends ConsumerWidget {
  const CartScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cart = ref.watch(cartProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        title: const Text('Your Cart'),
      ),
      body: cart.isEmpty
          ? const _EmptyCart()
          : SafeArea(
              child: Column(
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      padding: EdgeInsets.all(Responsive.pagePadding(context)),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 640),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (cart.restaurantName != null) ...[
                              Text(cart.restaurantName!, style: AppTextStyles.title),
                              const SizedBox(height: 16),
                            ],
                            for (final item in cart.items) _CartItemTile(item: item),
                          ],
                        ),
                      ),
                    ),
                  ),
                  _CartSummaryBar(
                    subtotalDisplay: cart.subtotalDisplay,
                    totalQuantity: cart.totalQuantity,
                  ),
                ],
              ),
            ),
    );
  }
}

class _CartItemTile extends ConsumerWidget {
  const _CartItemTile({required this.item});
  final CartItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(cartProvider.notifier);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: item.imageUrl != null
                ? Image.network(
                    item.imageUrl!,
                    width: 64,
                    height: 64,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => _placeholder(),
                  )
                : _placeholder(),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.name, style: AppTextStyles.title.copyWith(fontSize: 15)),
                const SizedBox(height: 4),
                Text(item.price, style: AppTextStyles.bodySmall.copyWith(color: AppColors.textMuted)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                item.subtotalDisplay,
                style: AppTextStyles.title.copyWith(color: AppColors.primaryDark, fontSize: 15),
              ),
              const SizedBox(height: 6),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _stepButton(Icons.remove, () => notifier.decrementItem(item.menuItemId)),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Text('${item.quantity}', style: AppTextStyles.bodySmall),
                  ),
                  _stepButton(Icons.add, () => notifier.incrementItem(item.menuItemId)),
                  const SizedBox(width: 4),
                  IconButton(
                    onPressed: () => notifier.removeItem(item.menuItemId),
                    icon: const Icon(Icons.delete_outline, size: 18, color: AppColors.error),
                    tooltip: 'Remove',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _stepButton(IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(color: AppColors.primaryLight, borderRadius: BorderRadius.circular(6)),
        child: Icon(icon, size: 14, color: AppColors.primaryDark),
      ),
    );
  }

  Widget _placeholder() {
    return Container(
      width: 64,
      height: 64,
      color: AppColors.primaryLight,
      child: const Icon(Icons.restaurant_rounded, color: AppColors.primaryDark, size: 24),
    );
  }
}

class _CartSummaryBar extends StatelessWidget {
  const _CartSummaryBar({required this.subtotalDisplay, required this.totalQuantity});
  final String subtotalDisplay;
  final int totalQuantity;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: const BoxDecoration(
          color: AppColors.surface,
          border: Border(top: BorderSide(color: AppColors.border)),
        ),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '$totalQuantity item(s)',
                        style: AppTextStyles.bodySmall.copyWith(color: AppColors.textMuted),
                      ),
                      Text(
                        'Subtotal: $subtotalDisplay',
                        style: AppTextStyles.title.copyWith(color: AppColors.primaryDark),
                      ),
                    ],
                  ),
                ),
                AppPrimaryButton(
                  label: 'Proceed to Order',
                  onPressed: () => context.push(AppRoutes.orderReview),
                ),
              ],
            ),
          ),
        ),
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
            const Icon(Icons.shopping_cart_outlined, size: 48, color: AppColors.textMuted),
            const SizedBox(height: 16),
            Text('Your cart is empty.', style: AppTextStyles.body.copyWith(color: AppColors.textSecondary)),
            const SizedBox(height: 20),
            AppOutlinedButton(label: 'Browse Menu', onPressed: () => Navigator.of(context).maybePop()),
          ],
        ),
      ),
    );
  }
}
