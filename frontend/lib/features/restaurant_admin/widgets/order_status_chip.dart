import 'package:flutter/material.dart';
import 'package:scanserve/core/theme/app_colors.dart';
import 'package:scanserve/core/theme/app_text_styles.dart';

Color _colorForStatus(String status) {
  switch (status) {
    case 'PENDING':
      return AppColors.primary;
    case 'ACCEPTED':
    case 'PREPARING':
      return const Color(0xFF3D7EDB);
    case 'READY':
      return AppColors.success;
    case 'CANCELLED':
    case 'REJECTED':
      return AppColors.error;
    default:
      return AppColors.textMuted;
  }
}

class OrderStatusChip extends StatelessWidget {
  const OrderStatusChip({super.key, required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final color = _colorForStatus(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        status,
        style: AppTextStyles.bodySmall
            .copyWith(color: color, fontWeight: FontWeight.w700, fontSize: 12),
      ),
    );
  }
}
