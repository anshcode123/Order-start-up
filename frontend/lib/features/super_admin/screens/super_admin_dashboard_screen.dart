import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:scanserve/core/constants/app_routes.dart';
import 'package:scanserve/core/network/api_exception.dart';
import 'package:scanserve/core/theme/app_colors.dart';
import 'package:scanserve/core/theme/app_text_styles.dart';
import 'package:scanserve/core/utils/responsive.dart';
import 'package:scanserve/features/super_admin/providers/restaurant_providers.dart';
import 'package:scanserve/features/super_admin/widgets/stat_card.dart';
import 'package:scanserve/shared/widgets/app_button.dart';
import 'package:scanserve/shared/widgets/status_badge.dart';

class SuperAdminDashboardScreen extends ConsumerWidget {
  const SuperAdminDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dashboardAsync = ref.watch(superAdminDashboardProvider);
    final isMobile = Responsive.isMobile(context);
    final columns = isMobile ? 2 : (Responsive.isTablet(context) ? 3 : 4);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(superAdminDashboardProvider),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.all(Responsive.pagePadding(context)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Platform Dashboard',
                          style: AppTextStyles.displayMedium),
                      const SizedBox(height: 4),
                      Text(
                        'Real-time overview of ScanServe platform activity',
                        style: AppTextStyles.bodySmall
                            .copyWith(color: AppColors.textMuted),
                      ),
                    ],
                  ),
                  IconButton(
                    tooltip: 'Refresh stats',
                    icon: const Icon(Icons.refresh,
                        color: AppColors.textSecondary),
                    onPressed: () =>
                        ref.invalidate(superAdminDashboardProvider),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              dashboardAsync.when(
                loading: () => const Padding(
                  padding: EdgeInsets.symmetric(vertical: 80),
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (error, _) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 40),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        apiErrorMessage(error),
                        style:
                            AppTextStyles.body.copyWith(color: AppColors.error),
                      ),
                      const SizedBox(height: 12),
                      AppPrimaryButton(
                        label: 'Retry',
                        onPressed: () =>
                            ref.invalidate(superAdminDashboardProvider),
                      ),
                    ],
                  ),
                ),
                data: (dashboard) => Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Statistics Grid (7 Core Phase 10 metrics)
                    GridView(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: columns,
                        mainAxisSpacing: 16,
                        crossAxisSpacing: 16,
                        childAspectRatio: isMobile ? 1.5 : 1.7,
                      ),
                      children: [
                        StatCard(
                          label: 'Total Restaurants',
                          value: dashboard.totalRestaurants,
                          icon: Icons.storefront_outlined,
                          accentColor: AppColors.primary,
                        ),
                        StatCard(
                          label: 'Active Restaurants',
                          value: dashboard.activeRestaurants,
                          icon: Icons.check_circle_outline,
                          accentColor: AppColors.success,
                        ),
                        StatCard(
                          label: 'Inactive',
                          value: dashboard.inactiveRestaurants,
                          icon: Icons.pause_circle_outline,
                          accentColor: AppColors.textMuted,
                        ),
                        StatCard(
                          label: 'Total Orders',
                          value: dashboard.totalOrders,
                          icon: Icons.receipt_long_outlined,
                          accentColor: AppColors.primaryDark,
                        ),
                        StatCard(
                          label: "Today's Orders",
                          value: dashboard.todayOrders,
                          icon: Icons.today_outlined,
                          accentColor: Colors.blue.shade700,
                        ),
                        StatCard(
                          label: 'Pending Orders',
                          value: dashboard.pendingOrders,
                          icon: Icons.pending_actions_outlined,
                          accentColor: Colors.orange.shade800,
                        ),
                        StatCard(
                          label: 'Completed Orders',
                          value: dashboard.completedOrders,
                          icon: Icons.done_all_outlined,
                          accentColor: AppColors.success,
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Quick Actions Banner
                    Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: AppColors.primaryLight.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: AppColors.primary.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.insights_outlined,
                              color: AppColors.primaryDark, size: 24),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Explore Detailed Platform Analytics',
                                  style: AppTextStyles.title
                                      .copyWith(fontSize: 15),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Analyze order volume by date range (Today, 7D, 30D), status breakdowns, and per-restaurant performance.',
                                  style: AppTextStyles.bodySmall
                                      .copyWith(color: AppColors.textMuted),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          AppPrimaryButton(
                            label: 'View Analytics',
                            onPressed: () =>
                                context.go(AppRoutes.superAdminAnalytics),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),

                    // Recent Restaurants Section
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Recent Restaurants',
                            style: AppTextStyles.title),
                        TextButton(
                          onPressed: () =>
                              context.go(AppRoutes.superAdminRestaurants),
                          child: const Text('View All Restaurants'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (dashboard.recentRestaurants.isEmpty)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Center(
                          child: Text(
                            'No restaurants created yet.',
                            style: AppTextStyles.bodySmall
                                .copyWith(color: AppColors.textMuted),
                          ),
                        ),
                      )
                    else
                      Container(
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Column(
                          children: [
                            for (int i = 0;
                                i < dashboard.recentRestaurants.length;
                                i++) ...[
                              if (i > 0)
                                const Divider(
                                    height: 1, color: AppColors.border),
                              ListTile(
                                contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 20, vertical: 8),
                                title: Text(
                                  dashboard.recentRestaurants[i].name,
                                  style: AppTextStyles.bodySmall.copyWith(
                                    color: AppColors.textPrimary,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                subtitle: Text(
                                  '/${dashboard.recentRestaurants[i].slug}',
                                  style: AppTextStyles.bodySmall
                                      .copyWith(color: AppColors.textMuted),
                                ),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    StatusBadge(
                                        isActive: dashboard
                                            .recentRestaurants[i].isActive),
                                    const SizedBox(width: 8),
                                    const Icon(Icons.chevron_right,
                                        size: 20, color: AppColors.textMuted),
                                  ],
                                ),
                                onTap: () => context.go(
                                  AppRoutes.superAdminRestaurantDetail(
                                    dashboard.recentRestaurants[i].id,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
