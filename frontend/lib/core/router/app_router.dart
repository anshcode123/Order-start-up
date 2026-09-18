import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:scanserve/core/constants/app_routes.dart';
import 'package:scanserve/features/auth/providers/auth_provider.dart';
import 'package:scanserve/features/auth/screens/login_screen.dart';
import 'package:scanserve/features/auth/state/auth_state.dart';
import 'package:scanserve/features/landing/screens/landing_screen.dart';
import 'package:scanserve/features/restaurant_admin/screens/categories_screen.dart';
import 'package:scanserve/features/restaurant_admin/screens/menu_item_form_screen.dart';
import 'package:scanserve/features/restaurant_admin/screens/menu_screen.dart';
import 'package:scanserve/features/restaurant_admin/screens/restaurant_admin_dashboard_screen.dart';
import 'package:scanserve/features/restaurant_admin/screens/restaurant_admin_qr_screen.dart';
import 'package:scanserve/features/restaurant_admin/screens/settings_screen.dart';
import 'package:scanserve/features/restaurant_admin/widgets/restaurant_admin_scaffold.dart';
import 'package:scanserve/features/super_admin/screens/restaurant_create_screen.dart';
import 'package:scanserve/features/super_admin/screens/restaurant_detail_screen.dart';
import 'package:scanserve/features/super_admin/screens/restaurant_qr_screen.dart';
import 'package:scanserve/features/super_admin/screens/restaurants_list_screen.dart';
import 'package:scanserve/features/super_admin/screens/super_admin_dashboard_screen.dart';
import 'package:scanserve/features/super_admin/widgets/super_admin_scaffold.dart';

/// Route table + auth guard.
///
/// NOTE ON THE PATTERN: this Provider watches authProvider, so the
/// whole GoRouter is rebuilt whenever auth status changes (login,
/// logout, or the initial bootstrap resolving). That's a deliberate
/// simplification instead of wiring up a Listenable bridge - it only
/// fires on actual auth transitions, not on ordinary in-app navigation,
/// and it's fine for those to reset to initialLocation since the
/// redirect below immediately sends the user to the right home anyway.
final appRouterProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authProvider);

  return GoRouter(
    initialLocation: AppRoutes.landing,
    redirect: (context, state) => _redirect(authState, state.matchedLocation),
    routes: [
      GoRoute(
        path: AppRoutes.landing,
        name: 'landing',
        builder: (context, state) => const LandingScreen(),
      ),
      GoRoute(
        path: AppRoutes.login,
        name: 'login',
        builder: (context, state) => const LoginScreen(),
      ),
      ShellRoute(
        builder: (context, state, child) => RestaurantAdminScaffold(child: child),
        routes: [
          GoRoute(
            path: AppRoutes.dashboard,
            name: 'dashboard',
            builder: (context, state) => const RestaurantAdminDashboardScreen(),
          ),
          GoRoute(
            path: AppRoutes.dashboardCategories,
            name: 'dashboard-categories',
            builder: (context, state) => const CategoriesScreen(),
          ),
          GoRoute(
            path: AppRoutes.dashboardMenu,
            name: 'dashboard-menu',
            builder: (context, state) => const MenuScreen(),
          ),
          GoRoute(
            path: AppRoutes.dashboardMenuItemCreate,
            name: 'dashboard-menu-item-create',
            builder: (context, state) => const MenuItemFormScreen(),
          ),
          GoRoute(
            path: AppRoutes.dashboardMenuItemEditTemplate,
            name: 'dashboard-menu-item-edit',
            builder: (context, state) =>
                MenuItemFormScreen(menuItemId: state.pathParameters['id']!),
          ),
          GoRoute(
            path: AppRoutes.dashboardQr,
            name: 'dashboard-qr',
            builder: (context, state) => const RestaurantAdminQrScreen(),
          ),
          GoRoute(
            path: AppRoutes.dashboardSettings,
            name: 'dashboard-settings',
            builder: (context, state) => const RestaurantAdminSettingsScreen(),
          ),
        ],
      ),
      ShellRoute(
        builder: (context, state, child) => SuperAdminScaffold(child: child),
        routes: [
          GoRoute(
            path: AppRoutes.superAdminDashboard,
            name: 'super-admin-dashboard',
            builder: (context, state) => const SuperAdminDashboardScreen(),
          ),
          GoRoute(
            path: AppRoutes.superAdminRestaurants,
            name: 'super-admin-restaurants',
            builder: (context, state) => const RestaurantsListScreen(),
          ),
          GoRoute(
            path: AppRoutes.superAdminRestaurantCreate,
            name: 'super-admin-restaurant-create',
            builder: (context, state) => const RestaurantCreateScreen(),
          ),
          GoRoute(
            path: AppRoutes.superAdminRestaurantDetailTemplate,
            name: 'super-admin-restaurant-detail',
            builder: (context, state) =>
                RestaurantDetailScreen(restaurantId: state.pathParameters['id']!),
          ),
          GoRoute(
            path: AppRoutes.superAdminRestaurantQrTemplate,
            name: 'super-admin-restaurant-qr',
            builder: (context, state) =>
                RestaurantQrScreen(restaurantId: state.pathParameters['id']!),
          ),
        ],
      ),
    ],
  );
});

String? _redirect(AuthState authState, String location) {
  // Still checking for a stored token - don't redirect yet, otherwise
  // every fresh page load would briefly bounce through /login.
  if (authState.status == AuthStatus.unknown) return null;

  final isLoggedIn = authState.status == AuthStatus.authenticated;
  final isProtectedRoute =
      location.startsWith('/dashboard') || location.startsWith('/super-admin');

  if (!isLoggedIn) {
    return isProtectedRoute ? AppRoutes.login : null;
  }

  final user = authState.user!;
  final homeForRole = user.isSuperAdmin ? AppRoutes.superAdminDashboard : AppRoutes.dashboard;

  final goingToPublicOnlyRoute =
      location == AppRoutes.login || location == AppRoutes.landing;
  if (goingToPublicOnlyRoute) return homeForRole;

  // Keep each role inside their own section.
  if (user.isSuperAdmin && location.startsWith('/dashboard')) {
    return AppRoutes.superAdminDashboard;
  }
  if (user.isRestaurantAdmin && location.startsWith('/super-admin')) {
    return AppRoutes.dashboard;
  }

  return null;
}
