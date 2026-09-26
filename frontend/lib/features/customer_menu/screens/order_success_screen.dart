import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:scanserve/core/network/api_exception.dart';
import 'package:scanserve/core/theme/app_colors.dart';
import 'package:scanserve/core/theme/app_text_styles.dart';
import 'package:scanserve/core/utils/responsive.dart';
import 'package:scanserve/features/customer_menu/providers/customer_order_socket_provider.dart';
import 'package:scanserve/features/customer_menu/providers/public_order_status_provider.dart';
import 'package:scanserve/features/restaurant_admin/widgets/order_status_chip.dart';
import 'package:scanserve/shared/models/order.dart';

/// Phase 13: COMPLETED is removed; READY is the final happy-path step.
const _progressSteps = ['PENDING', 'ACCEPTED', 'PREPARING', 'READY'];

class OrderSuccessScreen extends ConsumerWidget {
  const OrderSuccessScreen({
    super.key,
    required this.orderRef,
    this.initialOrder,
  });

  final String orderRef;
  final PlacedOrder? initialOrder;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(customerOrderSocketProvider(orderRef));
    final statusAsync = ref.watch(publicOrderStatusProvider(orderRef));
    final order = statusAsync.valueOrNull ?? initialOrder;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        title: const Text('Order Status'),
        automaticallyImplyLeading: false,
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(Responsive.pagePadding(context)),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: order != null
                ? _OrderConfirmationBody(order: order)
                : statusAsync.when(
                    loading: () => const Padding(
                      padding: EdgeInsets.symmetric(vertical: 80),
                      child: Center(child: CircularProgressIndicator()),
                    ),
                    error: (error, _) => Padding(
                      padding: const EdgeInsets.all(32),
                      child: Text(
                        apiErrorMessage(error),
                        textAlign: TextAlign.center,
                        style: AppTextStyles.body.copyWith(color: AppColors.error),
                      ),
                    ),
                    data: (fetched) => _OrderConfirmationBody(order: fetched),
                  ),
          ),
        ),
      ),
    );
  }
}

class _OrderConfirmationBody extends StatelessWidget {
  const _OrderConfirmationBody({required this.order});

  final PlacedOrder order;

  @override
  Widget build(BuildContext context) {
    final isTerminallyStopped = order.status == 'CANCELLED' || order.status == 'REJECTED';

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: isTerminallyStopped
                  ? AppColors.error.withValues(alpha: 0.12)
                  : AppColors.primaryLight,
              shape: BoxShape.circle,
            ),
            child: Icon(
              isTerminallyStopped ? Icons.close_rounded : Icons.check_rounded,
              color: isTerminallyStopped ? AppColors.error : AppColors.primaryDark,
              size: 32,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            order.status == 'READY' ? 'Your Order is Ready!' : 'Order Placed Successfully',
            style: AppTextStyles.displayMedium,
          ),
          const SizedBox(height: 6),
          Text(
            'Order #${order.orderNumber}',
            style: AppTextStyles.title.copyWith(color: AppColors.primaryDark),
          ),
          const SizedBox(height: 12),
          OrderStatusChip(status: order.status),
          const SizedBox(height: 20),
          if (!isTerminallyStopped) ...[
            _OrderProgressBar(currentStatus: order.status),
            const SizedBox(height: 20),
          ],
          if (order.restaurantName != null)
            Text(order.restaurantName!, style: AppTextStyles.body),
          const SizedBox(height: 4),
          Text(
            order.diningSummary,
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 20),
          const Divider(color: AppColors.border),
          const SizedBox(height: 12),
          for (final item in order.items)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '${item.quantity} × ${item.displayName}',
                      style: AppTextStyles.body.copyWith(color: AppColors.textPrimary),
                    ),
                  ),
                  Text('₹${item.subtotal}', style: AppTextStyles.title.copyWith(fontSize: 15)),
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
                '₹${order.total}',
                style: AppTextStyles.displayMedium.copyWith(
                  fontSize: 20,
                  color: AppColors.primaryDark,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _OrderProgressBar extends StatelessWidget {
  const _OrderProgressBar({required this.currentStatus});

  final String currentStatus;

  @override
  Widget build(BuildContext context) {
    final activeIndex = _progressSteps.indexOf(currentStatus);

    return Row(
      children: [
        for (int i = 0; i < _progressSteps.length; i++) ...[
          Expanded(
            child: Column(
              children: [
                Container(
                  height: 6,
                  decoration: BoxDecoration(
                    color: i <= activeIndex ? AppColors.primary : AppColors.border,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  _progressSteps[i],
                  style: AppTextStyles.bodySmall.copyWith(
                    fontSize: 10,
                    fontWeight: i == activeIndex ? FontWeight.w700 : FontWeight.w400,
                    color: i <= activeIndex ? AppColors.primaryDark : AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
          if (i < _progressSteps.length - 1) const SizedBox(width: 6),
        ],
      ],
    );
  }
}
