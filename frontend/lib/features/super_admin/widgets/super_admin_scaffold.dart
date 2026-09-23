import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:scanserve/core/constants/app_routes.dart';
import 'package:scanserve/core/theme/app_colors.dart';
import 'package:scanserve/core/theme/app_text_styles.dart';
import 'package:scanserve/core/utils/responsive.dart';
import 'package:scanserve/features/auth/providers/auth_provider.dart';
import 'package:scanserve/shared/widgets/app_logo.dart';

/// Nav shown on every Super Admin page: Dashboard, Restaurants,
/// Create Restaurant, Logout. Per Phase 3 spec this does NOT show
/// restaurant-specific menu/order pages - those don't exist for a
/// Super Admin.
class SuperAdminScaffold extends ConsumerWidget {
  const SuperAdminScaffold({super.key, required this.child});

  final Widget child;

  static const _navItems = [
    (
      label: 'Dashboard',
      icon: Icons.dashboard_outlined,
      route: AppRoutes.superAdminDashboard
    ),
    (
      label: 'Analytics',
      icon: Icons.insights_outlined,
      route: AppRoutes.superAdminAnalytics
    ),
    (
      label: 'Restaurants',
      icon: Icons.storefront_outlined,
      route: AppRoutes.superAdminRestaurants
    ),
    (
      label: 'Create Restaurant',
      icon: Icons.add_business_outlined,
      route: AppRoutes.superAdminRestaurantCreate,
    ),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDesktop = Responsive.isDesktop(context);
    final currentLocation = GoRouterState.of(context).matchedLocation;

    if (isDesktop) {
      return Scaffold(
        backgroundColor: AppColors.background,
        body: Row(
          children: [
            _SideNav(currentLocation: currentLocation),
            Expanded(child: child),
          ],
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const AppLogo(fontSize: 18),
        backgroundColor: AppColors.surface,
      ),
      drawer: Drawer(
          child: _SideNav(currentLocation: currentLocation, isDrawer: true)),
      body: child,
    );
  }
}

class _SideNav extends ConsumerWidget {
  const _SideNav({required this.currentLocation, this.isDrawer = false});

  final String currentLocation;
  final bool isDrawer;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      width: isDrawer ? null : 240,
      color: AppColors.surface,
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (!isDrawer) ...[
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: AppLogo(fontSize: 18),
            ),
            const SizedBox(height: 28),
          ],
          for (final item in SuperAdminScaffold._navItems)
            _NavTile(
              label: item.label,
              icon: item.icon,
              selected: currentLocation == item.route,
              onTap: () {
                if (isDrawer) Navigator.of(context).pop();
                context.go(item.route);
              },
            ),
          const Spacer(),
          const Divider(height: 1, color: AppColors.border),
          _NavTile(
            label: 'Logout',
            icon: Icons.logout,
            selected: false,
            onTap: () => ref.read(authProvider.notifier).logout(),
          ),
        ],
      ),
    );
  }
}

class _NavTile extends StatelessWidget {
  const _NavTile({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppColors.primaryLight : Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          child: Row(
            children: [
              Icon(icon,
                  size: 20,
                  color: selected
                      ? AppColors.primaryDark
                      : AppColors.textSecondary),
              const SizedBox(width: 12),
              Text(
                label,
                style: AppTextStyles.bodySmall.copyWith(
                  color:
                      selected ? AppColors.primaryDark : AppColors.textPrimary,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
