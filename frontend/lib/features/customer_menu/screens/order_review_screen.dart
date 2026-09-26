import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:scanserve/core/constants/app_routes.dart';
import 'package:scanserve/core/theme/app_colors.dart';
import 'package:scanserve/core/theme/app_text_styles.dart';
import 'package:scanserve/core/utils/responsive.dart';
import 'package:scanserve/features/customer_menu/providers/cart_provider.dart';
import 'package:scanserve/features/customer_menu/providers/order_submission_provider.dart';
import 'package:scanserve/features/customer_menu/providers/public_menu_provider.dart';
import 'package:scanserve/features/customer_menu/providers/table_number_provider.dart';
import 'package:scanserve/shared/widgets/app_button.dart';
import 'package:scanserve/shared/widgets/app_dialogs.dart';

class OrderReviewScreen extends ConsumerWidget {
  const OrderReviewScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cart = ref.watch(cartProvider);
    final diningType = ref.watch(diningTypeProvider);
    final tableNumber = ref.watch(tableNumberProvider);
    final submission = ref.watch(orderSubmissionProvider);
    final menuAsync = cart.restaurantSlug != null
        ? ref.watch(publicMenuProvider(cart.restaurantSlug!))
        : null;
    final requireTableNumber = menuAsync?.valueOrNull?.restaurant.requireTableNumber ?? true;

    ref.listen<OrderSubmissionState>(orderSubmissionProvider, (previous, next) {
      if (next.status == OrderSubmissionStatus.success && next.order != null) {
        context.go(AppRoutes.orderSuccess(next.order!.orderId), extra: next.order);
      } else if (next.status == OrderSubmissionStatus.failure && next.errorMessage != null) {
        showErrorSnackBar(context, next.errorMessage!);
      }
    });

    final missingRequiredTable = diningType == 'DINE_IN' &&
        requireTableNumber &&
        (tableNumber == null || tableNumber.trim().isEmpty);

    if (cart.isEmpty || missingRequiredTable) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(backgroundColor: AppColors.surface, title: const Text('Review Order')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  missingRequiredTable
                      ? 'Please enter your table number for Dine In.'
                      : 'Nothing to review yet.',
                  style: AppTextStyles.title,
                ),
                const SizedBox(height: 12),
                AppPrimaryButton(
                  label: 'Back to Cart',
                  onPressed: () => context.go(AppRoutes.cart),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final diningLabel = diningType == 'TAKEAWAY' ? 'Takeaway' : 'Dine In';
    final hasTable =
        diningType == 'DINE_IN' && tableNumber != null && tableNumber.trim().isNotEmpty;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        title: const Text('Review Order'),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(Responsive.pagePadding(context)),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (cart.restaurantName != null) ...[
                    Text(cart.restaurantName!, style: AppTextStyles.displayMedium),
                    const SizedBox(height: 8),
                  ],
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppColors.primaryLight,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          diningType == 'TAKEAWAY'
                              ? Icons.takeout_dining_outlined
                              : Icons.table_bar_outlined,
                          size: 18,
                          color: AppColors.primaryDark,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          hasTable ? '$diningLabel · Table $tableNumber' : diningLabel,
                          style: AppTextStyles.title.copyWith(
                            fontSize: 15,
                            color: AppColors.primaryDark,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Divider(color: AppColors.border),
                  const SizedBox(height: 12),
                  for (final item in cart.items)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              '${item.quantity} × ${item.displayName}',
                              style: AppTextStyles.body.copyWith(color: AppColors.textPrimary),
                            ),
                          ),
                          Text(
                            '₹${item.subtotal.toStringAsFixed(2)}',
                            style: AppTextStyles.title.copyWith(fontSize: 15),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 12),
                  const Divider(color: AppColors.border),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const Text('Total', style: AppTextStyles.title),
                      const Spacer(),
                      Text(
                        cart.formattedTotal,
                        style: AppTextStyles.displayMedium.copyWith(
                          fontSize: 22,
                          color: AppColors.primaryDark,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  AppPrimaryButton(
                    label: submission.isSubmitting ? 'Placing Order...' : 'Place Order',
                    expand: true,
                    onPressed: submission.isSubmitting
                        ? null
                        : () => ref.read(orderSubmissionProvider.notifier).submit(),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
