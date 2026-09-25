import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:scanserve/core/network/api_exception.dart';
import 'package:scanserve/core/theme/app_colors.dart';
import 'package:scanserve/core/theme/app_text_styles.dart';
import 'package:scanserve/core/utils/responsive.dart';
import 'package:scanserve/features/super_admin/providers/subscription_providers.dart';
import 'package:scanserve/shared/widgets/subscription_status_badge.dart';

class RestaurantAdminSubscriptionScreen extends ConsumerWidget {
  const RestaurantAdminSubscriptionScreen({super.key});

  String _formatDate(DateTime? dt) {
    if (dt == null) return '-';
    return dt.toLocal().toString().split(' ').first;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final subAsync = ref.watch(restaurantOwnSubscriptionProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(restaurantOwnSubscriptionProvider),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.all(Responsive.pagePadding(context)),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Subscription & Plan', style: AppTextStyles.displayMedium),
                const SizedBox(height: 4),
                Text(
                  'View your current ScanServe subscription plan, usage limits, and renewal status',
                  style: AppTextStyles.bodySmall.copyWith(color: AppColors.textMuted),
                ),
                const SizedBox(height: 24),
                subAsync.when(
                  loading: () => const Padding(
                    padding: EdgeInsets.symmetric(vertical: 80),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                  error: (error, _) => Text(
                    apiErrorMessage(error),
                    style: AppTextStyles.body.copyWith(color: AppColors.error),
                  ),
                  data: (sub) {
                    final isBlocked = sub.status == 'EXPIRED' ||
                        sub.status == 'SUSPENDED' ||
                        sub.status == 'CANCELLED';

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (isBlocked)
                          Container(
                            width: double.infinity,
                            margin: const EdgeInsets.only(bottom: 20),
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: AppColors.error.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: AppColors.error),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.warning_amber_rounded, color: AppColors.error),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    'Your subscription is ${sub.status}. Public online ordering is paused until your subscription is renewed. Please contact ScanServe Support.',
                                    style: AppTextStyles.bodySmall.copyWith(
                                      color: AppColors.error,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '${sub.plan.name} PLAN',
                                        style: AppTextStyles.displayMedium.copyWith(fontSize: 22),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        '₹${sub.plan.priceMonthly} / month',
                                        style: AppTextStyles.body.copyWith(
                                          color: AppColors.primaryDark,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                  SubscriptionStatusBadge(status: sub.status),
                                ],
                              ),
                              const Divider(height: 32),
                              _DetailRow('Start Date', _formatDate(sub.startDate)),
                              _DetailRow('End / Renewal Date', _formatDate(sub.endDate ?? sub.trialEndsAt)),
                              if (sub.daysRemaining != null)
                                _DetailRow('Days Remaining', '${sub.daysRemaining} days'),
                              _DetailRow(
                                'Categories Used',
                                '${sub.usage?.categoriesUsed ?? 0} / ${sub.plan.maxCategories?.toString() ?? "Unlimited"}',
                              ),
                              _DetailRow(
                                'Menu Items Used',
                                '${sub.usage?.menuItemsUsed ?? 0} / ${sub.plan.maxMenuItems?.toString() ?? "Unlimited"}',
                              ),
                              _DetailRow(
                                'WhatsApp Order Notifications',
                                sub.plan.whatsappEnabled ? 'Enabled' : 'Not Included',
                              ),
                            ],
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow(this.label, this.value);
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: AppTextStyles.bodySmall.copyWith(color: AppColors.textMuted)),
          Text(
            value,
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
