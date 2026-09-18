import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:scanserve/core/constants/app_routes.dart';
import 'package:scanserve/core/network/api_exception.dart';
import 'package:scanserve/core/theme/app_colors.dart';
import 'package:scanserve/core/theme/app_text_styles.dart';
import 'package:scanserve/core/utils/responsive.dart';
import 'package:scanserve/features/auth/providers/auth_provider.dart';
import 'package:scanserve/features/restaurant_admin/providers/menu_providers.dart';
import 'package:scanserve/features/super_admin/widgets/stat_card.dart';

/// Confirms the Restaurant Admin is correctly associated with their
/// restaurant (Phase 3), and now also shows real menu stats fetched
/// from GET /api/restaurant/dashboard (Phase 4 spec #19). Reuses the
/// same StatCard widget the Super Admin dashboard uses - no second
/// stats-card implementation.
class RestaurantAdminDashboardScreen extends ConsumerWidget {
  const RestaurantAdminDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider).user;
    final statsAsync = ref.watch(restaurantAdminStatsProvider);
    final columns = Responsive.isMobile(context) ? 1 : 2;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(restaurantAdminStatsProvider),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.all(Responsive.pagePadding(context)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                user?.restaurantName != null ? 'Welcome to ${user!.restaurantName}' : 'Welcome',
                style: AppTextStyles.displayMedium,
              ),
              const SizedBox(height: 4),
              Text(
                '${user?.name ?? '-'} · ${user?.role ?? '-'}',
                style: AppTextStyles.bodySmall.copyWith(color: AppColors.textMuted),
              ),
              const SizedBox(height: 24),
              statsAsync.when(
                loading: () => const Padding(
                  padding: EdgeInsets.symmetric(vertical: 60),
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (error, _) => Text(
                  apiErrorMessage(error),
                  style: AppTextStyles.body.copyWith(color: AppColors.error),
                ),
                data: (stats) => GridView.count(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: columns,
                  mainAxisSpacing: 16,
                  crossAxisSpacing: 16,
                  childAspectRatio: columns == 1 ? 2.6 : 1.8,
                  children: [
                    StatCard(label: 'Categories', value: stats.totalCategories),
                    StatCard(label: 'Menu Items', value: stats.totalMenuItems),
                    StatCard(
                      label: 'Available',
                      value: stats.availableItems,
                      accentColor: AppColors.success,
                    ),
                    StatCard(
                      label: 'Unavailable',
                      value: stats.unavailableItems,
                      accentColor: AppColors.textMuted,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Manage your categories and menu items to keep this up to date.',
                        style: AppTextStyles.bodySmall.copyWith(color: AppColors.textPrimary),
                      ),
                    ),
                    TextButton(
                      onPressed: () => context.go(AppRoutes.dashboardMenu),
                      child: const Text('Go to Menu'),
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
