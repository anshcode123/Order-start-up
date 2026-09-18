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
import 'package:scanserve/shared/widgets/status_badge.dart';

class SuperAdminDashboardScreen extends ConsumerWidget {
  const SuperAdminDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dashboardAsync = ref.watch(superAdminDashboardProvider);
    final columns = Responsive.isMobile(context) ? 1 : 3;

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
              Text('Dashboard', style: AppTextStyles.displayMedium),
              const SizedBox(height: 24),
              dashboardAsync.when(
                loading: () => const Padding(
                  padding: EdgeInsets.symmetric(vertical: 60),
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (error, _) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 40),
                  child: Text(
                    apiErrorMessage(error),
                    style: AppTextStyles.body.copyWith(color: AppColors.error),
                  ),
                ),
                data: (dashboard) => Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    GridView.count(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisCount: columns,
                      mainAxisSpacing: 16,
                      crossAxisSpacing: 16,
                      childAspectRatio: columns == 1 ? 2.6 : 1.6,
                      children: [
                        StatCard(label: 'Total Restaurants', value: dashboard.totalRestaurants),
                        StatCard(
                          label: 'Active',
                          value: dashboard.activeRestaurants,
                          accentColor: AppColors.success,
                        ),
                        StatCard(
                          label: 'Inactive',
                          value: dashboard.inactiveRestaurants,
                          accentColor: AppColors.textMuted,
                        ),
                      ],
                    ),
                    const SizedBox(height: 32),
                    Text('Recent Restaurants', style: AppTextStyles.title),
                    const SizedBox(height: 12),
                    if (dashboard.recentRestaurants.isEmpty)
                      Text(
                        'No restaurants yet.',
                        style: AppTextStyles.bodySmall.copyWith(color: AppColors.textMuted),
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
                            for (final restaurant in dashboard.recentRestaurants)
                              ListTile(
                                title: Text(restaurant.name, style: AppTextStyles.bodySmall.copyWith(
                                  color: AppColors.textPrimary,
                                  fontWeight: FontWeight.w500,
                                )),
                                subtitle: Text('/${restaurant.slug}', style: AppTextStyles.bodySmall),
                                trailing: StatusBadge(isActive: restaurant.isActive),
                                onTap: () => context
                                    .go(AppRoutes.superAdminRestaurantDetail(restaurant.id)),
                              ),
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
