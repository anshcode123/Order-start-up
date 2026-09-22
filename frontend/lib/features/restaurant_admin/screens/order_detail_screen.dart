import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:scanserve/core/network/api_exception.dart';
import 'package:scanserve/core/network/dio_client.dart';
import 'package:scanserve/core/theme/app_colors.dart';
import 'package:scanserve/core/theme/app_text_styles.dart';
import 'package:scanserve/core/utils/responsive.dart';
import 'package:scanserve/features/restaurant_admin/providers/order_providers.dart';
import 'package:scanserve/features/restaurant_admin/widgets/order_status_chip.dart';
import 'package:scanserve/shared/models/order_status.dart';
import 'package:scanserve/shared/models/restaurant_order.dart';
import 'package:scanserve/shared/widgets/app_dialogs.dart';

/// /dashboard/orders/:id - full order detail + status update controls
/// (Phase 6 spec #13, #14). The backend is still the real enforcement
/// point for valid transitions; this screen only offers buttons for
/// transitions that are already known-valid, so a rejected request here
/// would only ever mean the two sides drifted, not that the UI is the
/// source of truth.
class OrderDetailScreen extends ConsumerStatefulWidget {
  const OrderDetailScreen({super.key, required this.orderId});

  final String orderId;

  @override
  ConsumerState<OrderDetailScreen> createState() => _OrderDetailScreenState();
}

class _OrderDetailScreenState extends ConsumerState<OrderDetailScreen> {
  bool _isUpdating = false;

  Future<void> _updateStatus(String nextStatus) async {
    final confirmed = await showConfirmDialog(
      context,
      title: 'Update order status?',
      message: 'Mark this order as $nextStatus?',
      confirmLabel: 'Confirm',
    );
    if (!confirmed) return;

    setState(() => _isUpdating = true);
    try {
      final dio = ref.read(dioProvider);
      await dio.patch('/restaurant/orders/${widget.orderId}/status', data: {'status': nextStatus});
      ref.invalidate(restaurantOrderDetailProvider(widget.orderId));
      ref.invalidate(restaurantOrdersProvider);
      if (mounted) showSuccessSnackBar(context, 'Order marked as $nextStatus');
    } catch (error) {
      if (mounted) showErrorSnackBar(context, apiErrorMessage(error));
    } finally {
      if (mounted) setState(() => _isUpdating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final orderAsync = ref.watch(restaurantOrderDetailProvider(widget.orderId));

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(backgroundColor: AppColors.surface, title: const Text('Order Details')),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(Responsive.pagePadding(context)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: orderAsync.when(
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: 60),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (error, _) => Text(
              apiErrorMessage(error),
              style: AppTextStyles.body.copyWith(color: AppColors.error),
            ),
            data: (order) => _buildDetail(order),
          ),
        ),
      ),
    );
  }

  Widget _buildDetail(RestaurantOrder order) {
    final nextStatuses = nextStatusesFor(order.status);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Order #${order.id.substring(0, 8).toUpperCase()}',
              style: AppTextStyles.displayMedium.copyWith(fontSize: 24),
            ),
            const SizedBox(width: 12),
            OrderStatusChip(status: order.status),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'Placed ${order.createdAt.toLocal()}',
          style: AppTextStyles.bodySmall.copyWith(color: AppColors.textMuted),
        ),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.primaryLight,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: [
              const Icon(Icons.table_bar_outlined, color: AppColors.primaryDark),
              const SizedBox(width: 8),
              Text('Table ${order.tableNumber}', style: AppTextStyles.title.copyWith(fontSize: 16)),
            ],
          ),
        ),
        const SizedBox(height: 24),
        Text('Items', style: AppTextStyles.title),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border),
          ),
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              for (final item in order.items)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(item.itemName, style: AppTextStyles.bodySmall.copyWith(color: AppColors.textPrimary)),
                      ),
                      Text(
                        '${item.quantity} × ${item.unitPrice}',
                        style: AppTextStyles.bodySmall.copyWith(color: AppColors.textMuted),
                      ),
                      const SizedBox(width: 12),
                      SizedBox(
                        width: 70,
                        child: Text(
                          item.subtotal,
                          textAlign: TextAlign.right,
                          style: AppTextStyles.bodySmall.copyWith(color: AppColors.textPrimary, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                ),
              const Divider(color: AppColors.border),
              Row(
                children: [
                  Text('Total', style: AppTextStyles.title),
                  const Spacer(),
                  Text(order.total, style: AppTextStyles.title.copyWith(color: AppColors.primaryDark)),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        if (nextStatuses.isNotEmpty) ...[
          Text('Update Status', style: AppTextStyles.title),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final status in nextStatuses)
                FilledButton(
                  onPressed: _isUpdating ? null : () => _updateStatus(status),
                  style: FilledButton.styleFrom(
                    backgroundColor: status == 'REJECTED' || status == 'CANCELLED'
                        ? AppColors.error
                        : AppColors.primary,
                  ),
                  child: Text(status),
                ),
            ],
          ),
        ] else
          Text(
            'This order is in a final state and cannot be changed further.',
            style: AppTextStyles.bodySmall.copyWith(color: AppColors.textMuted),
          ),
      ],
    );
  }
}
