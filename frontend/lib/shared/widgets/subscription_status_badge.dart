import 'package:flutter/material.dart';
import 'package:scanserve/core/theme/app_colors.dart';
import 'package:scanserve/core/theme/app_text_styles.dart';

class SubscriptionStatusBadge extends StatelessWidget {
  const SubscriptionStatusBadge({super.key, required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final normalized = status.toUpperCase();
    final (Color bg, Color fg) = switch (normalized) {
      'ACTIVE' => (AppColors.success.withValues(alpha: 0.14), AppColors.success),
      'TRIAL' => (Colors.blue.shade50, Colors.blue.shade700),
      'EXPIRED' => (Colors.orange.shade50, Colors.orange.shade800),
      'SUSPENDED' => (AppColors.error.withValues(alpha: 0.14), AppColors.error),
      'CANCELLED' => (Colors.grey.shade200, AppColors.textMuted),
      _ => (Colors.grey.shade200, AppColors.textSecondary),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        normalized,
        style: AppTextStyles.bodySmall.copyWith(
          color: fg,
          fontWeight: FontWeight.w700,
          fontSize: 11,
        ),
      ),
    );
  }
}
