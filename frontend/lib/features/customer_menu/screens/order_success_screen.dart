import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:scanserve/core/network/api_exception.dart';
import 'package:scanserve/core/network/socket_connection_status.dart';
import 'package:scanserve/core/theme/app_colors.dart';
import 'package:scanserve/core/theme/app_text_styles.dart';
import 'package:scanserve/core/utils/responsive.dart';
import 'package:scanserve/features/customer_menu/providers/customer_order_socket_provider.dart';
import 'package:scanserve/features/customer_menu/providers/public_order_status_provider.dart';
import 'package:scanserve/shared/models/order.dart';
import 'package:scanserve/shared/widgets/app_button.dart';

/// The normal, in-order progression a placed order moves through.
/// CANCELLED/REJECTED are deliberately not part of this list - they get
/// their own terminal state below rather than being squeezed into a
/// step position (Phase 7 spec #11).
const _happyPathStatuses = [
  'PENDING',
  'ACCEPTED',
  'PREPARING',
  'READY',
  'COMPLETED'
];

/// /order/success/:orderRef - shown right after a successful
/// POST /api/public/orders, and also works as a general "check my order
/// status" page if revisited later. Now live (Phase 7): connects to the
/// order's own Socket.IO room and updates the moment the restaurant
/// changes status, with REST as the fallback/resync source of truth on
/// connect and reconnect.
class OrderSuccessScreen extends ConsumerWidget {
  const OrderSuccessScreen({super.key, required this.orderRef});

  final String orderRef;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final orderAsync = ref.watch(publicOrderStatusProvider(orderRef));
    // Watching (not just reading) is what keeps the socket alive for as
    // long as this screen is on screen, and tears it down automatically
    // when the customer navigates away (Phase 7 spec #23).
    final connectionStatus = ref.watch(customerOrderSocketProvider(orderRef));

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        title: const Text('Order Status'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(child: _ConnectionBadge(status: connectionStatus)),
          ),
        ],
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(Responsive.pagePadding(context)),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: orderAsync.when(
              loading: () => const Padding(
                padding: EdgeInsets.symmetric(vertical: 60),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (error, _) => _ErrorState(message: apiErrorMessage(error)),
              data: (order) => _OrderSuccessCard(order: order),
            ),
          ),
        ),
      ),
    );
  }
}

class _ConnectionBadge extends StatelessWidget {
  const _ConnectionBadge({required this.status});
  final SocketConnectionStatus status;

  @override
  Widget build(BuildContext context) {
    final (color, label) = switch (status) {
      SocketConnectionStatus.connected => (AppColors.success, 'Live'),
      SocketConnectionStatus.connecting => (AppColors.textMuted, 'Connecting'),
      SocketConnectionStatus.disconnected => (
          AppColors.textMuted,
          'Reconnecting'
        ),
      SocketConnectionStatus.error => (AppColors.error, 'Offline'),
    };

    return Tooltip(
      message: '$label - updates automatically',
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 6),
          Text(label,
              style: AppTextStyles.bodySmall
                  .copyWith(color: AppColors.textMuted, fontSize: 11)),
        ],
      ),
    );
  }
}

class _OrderSuccessCard extends StatelessWidget {
  const _OrderSuccessCard({required this.order});
  final PlacedOrder order;

  @override
  Widget build(BuildContext context) {
    final isTerminalNegative =
        order.status == 'CANCELLED' || order.status == 'REJECTED';

    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            isTerminalNegative
                ? Icons.cancel_rounded
                : Icons.check_circle_rounded,
            color: isTerminalNegative ? AppColors.error : AppColors.success,
            size: 44,
          ),
          const SizedBox(height: 12),
          Text(isTerminalNegative ? _title(order.status) : 'Order Placed',
              style: AppTextStyles.headline),
          const SizedBox(height: 4),
          Text(
            'Order #${order.orderNumber}',
            style: AppTextStyles.bodySmall.copyWith(color: AppColors.textMuted),
          ),
          const SizedBox(height: 20),
          _row('Table', order.tableNumber),
          _row('Total', order.total),
          const SizedBox(height: 20),
          if (isTerminalNegative)
            _TerminalStatusBanner(status: order.status)
          else
            _StatusProgressStepper(currentStatus: order.status),
          const SizedBox(height: 20),
          const Divider(color: AppColors.border),
          const SizedBox(height: 12),
          for (final item in order.items)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '${item.itemName} × ${item.quantity}',
                      style: AppTextStyles.bodySmall
                          .copyWith(color: AppColors.textPrimary),
                    ),
                  ),
                  Text(item.subtotal,
                      style: AppTextStyles.bodySmall
                          .copyWith(color: AppColors.textPrimary)),
                ],
              ),
            ),
          const SizedBox(height: 24),
          AppOutlinedButton(
            label: 'Back to Menu',
            expand: true,
            onPressed: () =>
                Navigator.of(context).popUntil((route) => route.isFirst),
          ),
        ],
      ),
    );
  }

  String _title(String status) =>
      status == 'CANCELLED' ? 'Order Cancelled' : 'Order Rejected';

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Text(label,
              style:
                  AppTextStyles.bodySmall.copyWith(color: AppColors.textMuted)),
          const SizedBox(width: 8),
          Text(value, style: AppTextStyles.title.copyWith(fontSize: 15)),
        ],
      ),
    );
  }
}

/// PENDING -> ACCEPTED -> PREPARING -> READY -> COMPLETED, with the
/// current step highlighted and only steps up to (and including) it
/// marked done - a status that hasn't happened yet is never shown as
/// complete (Phase 7 spec #11).
class _StatusProgressStepper extends StatelessWidget {
  const _StatusProgressStepper({required this.currentStatus});
  final String currentStatus;

  @override
  Widget build(BuildContext context) {
    final currentIndex = _happyPathStatuses.indexOf(currentStatus);

    return Column(
      children: [
        for (var i = 0; i < _happyPathStatuses.length; i++)
          _StepRow(
            label: _happyPathStatuses[i],
            isDone: currentIndex >= 0 && i < currentIndex,
            isCurrent: i == currentIndex,
            isLast: i == _happyPathStatuses.length - 1,
          ),
      ],
    );
  }
}

class _StepRow extends StatelessWidget {
  const _StepRow({
    required this.label,
    required this.isDone,
    required this.isCurrent,
    required this.isLast,
  });

  final String label;
  final bool isDone;
  final bool isCurrent;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final isActive = isDone || isCurrent;
    final color = isActive ? AppColors.primary : AppColors.border;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  color: isActive ? AppColors.primary : AppColors.surface,
                  shape: BoxShape.circle,
                  border: Border.all(color: color, width: 2),
                ),
                child: isDone
                    ? const Icon(Icons.check, size: 12, color: Colors.white)
                    : null,
              ),
              if (!isLast) Expanded(child: Container(width: 2, color: color)),
            ],
          ),
          const SizedBox(width: 12),
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Text(
              label,
              style: AppTextStyles.bodySmall.copyWith(
                color: isCurrent
                    ? AppColors.primaryDark
                    : (isActive ? AppColors.textPrimary : AppColors.textMuted),
                fontWeight: isCurrent ? FontWeight.w700 : FontWeight.w400,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TerminalStatusBanner extends StatelessWidget {
  const _TerminalStatusBanner({required this.status});
  final String status;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.error.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
      ),
      child: Text(
        status == 'CANCELLED'
            ? 'This order was cancelled.'
            : 'This order was rejected by the restaurant.',
        style: AppTextStyles.bodySmall
            .copyWith(color: AppColors.error, fontWeight: FontWeight.w600),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline, size: 40, color: AppColors.textMuted),
          const SizedBox(height: 12),
          Text(message,
              textAlign: TextAlign.center,
              style:
                  AppTextStyles.body.copyWith(color: AppColors.textSecondary)),
        ],
      ),
    );
  }
}
