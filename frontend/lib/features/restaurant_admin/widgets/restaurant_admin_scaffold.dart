import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:scanserve/core/constants/app_routes.dart';
import 'package:scanserve/core/network/socket_connection_status.dart';
import 'package:scanserve/core/theme/app_colors.dart';
import 'package:scanserve/core/theme/app_text_styles.dart';
import 'package:scanserve/core/utils/responsive.dart';
import 'package:scanserve/features/auth/providers/auth_provider.dart';
import 'package:scanserve/features/restaurant_admin/providers/order_providers.dart';
import 'package:scanserve/features/restaurant_admin/providers/restaurant_order_socket_provider.dart';
import 'package:scanserve/shared/widgets/app_logo.dart';

class RestaurantAdminScaffold extends ConsumerWidget {
  const RestaurantAdminScaffold({super.key, required this.child});

  final Widget child;

  static const _navItems = [
    (label: 'Dashboard', icon: Icons.dashboard_outlined, route: AppRoutes.dashboard),
    (label: 'Orders', icon: Icons.receipt_long_outlined, route: AppRoutes.dashboardOrders),
    (label: 'Menu', icon: Icons.restaurant_menu_outlined, route: AppRoutes.dashboardMenu),
    (label: 'Categories', icon: Icons.category_outlined, route: AppRoutes.dashboardCategories),
    (label: 'QR', icon: Icons.qr_code_2_rounded, route: AppRoutes.dashboardQr),
    (label: 'Subscription', icon: Icons.card_membership_outlined, route: AppRoutes.dashboardSubscription),
    (label: 'Settings', icon: Icons.settings_outlined, route: AppRoutes.dashboardSettings),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDesktop = Responsive.isDesktop(context);
    final currentLocation = GoRouterState.of(context).matchedLocation;
    final connectionStatus = ref.watch(restaurantOrderSocketProvider);

    ref.listen(newOrderEventProvider, (previous, next) {
      if (next == null) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('New order received — ${next.diningSummary}'),
          backgroundColor: AppColors.primary,
          action: SnackBarAction(
            label: 'View',
            textColor: Colors.white,
            onPressed: () => context.go(AppRoutes.dashboardOrders),
          ),
        ),
      );
    });

    if (isDesktop) {
      return Scaffold(
        backgroundColor: AppColors.background,
        body: Row(
          children: [
            _SideNav(currentLocation: currentLocation, connectionStatus: connectionStatus),
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
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(child: _ConnectionDot(status: connectionStatus)),
          ),
        ],
      ),
      drawer: Drawer(
        child: _SideNav(currentLocation: currentLocation, connectionStatus: connectionStatus, isDrawer: true),
      ),
      body: child,
    );
  }
}

class _SideNav extends ConsumerWidget {
  const _SideNav({required this.currentLocation, required this.connectionStatus, this.isDrawer = false});

  final String currentLocation;
  final SocketConnectionStatus connectionStatus;
  final bool isDrawer;

  bool _isSelected(String route) {
    if (route == AppRoutes.dashboard) return currentLocation == route;
    return currentLocation.startsWith(route);
  }

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
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  const AppLogo(fontSize: 18),
                  const Spacer(),
                  _ConnectionDot(status: connectionStatus),
                ],
              ),
            ),
            const SizedBox(height: 28),
          ],
          for (final item in RestaurantAdminScaffold._navItems)
            _NavTile(
              label: item.label,
              icon: item.icon,
              selected: _isSelected(item.route),
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

class _ConnectionDot extends StatelessWidget {
  const _ConnectionDot({required this.status});

  final SocketConnectionStatus status;

  @override
  Widget build(BuildContext context) {
    final (color, label) = switch (status) {
      SocketConnectionStatus.connected => (AppColors.success, 'Live'),
      SocketConnectionStatus.connecting => (AppColors.textMuted, 'Connecting'),
      SocketConnectionStatus.disconnected => (AppColors.textMuted, 'Reconnecting'),
      SocketConnectionStatus.error => (AppColors.error, 'Offline'),
    };

    return Tooltip(
      message: '$label order updates',
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(label, style: AppTextStyles.bodySmall.copyWith(color: AppColors.textMuted, fontSize: 11)),
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
              Icon(icon, size: 20, color: selected ? AppColors.primaryDark : AppColors.textSecondary),
              const SizedBox(width: 12),
              Text(
                label,
                style: AppTextStyles.bodySmall.copyWith(
                  color: selected ? AppColors.primaryDark : AppColors.textPrimary,
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
