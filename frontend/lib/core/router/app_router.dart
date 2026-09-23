import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:scanserve/core/constants/app_routes.dart';
import 'package:scanserve/features/auth/providers/auth_provider.dart';
import 'package:scanserve/features/auth/screens/login_screen.dart';
import 'package:scanserve/features/auth/state/auth_state.dart';
import 'package:scanserve/features/customer_menu/screens/cart_screen.dart';
import 'package:scanserve/features/customer_menu/screens/order_review_screen.dart';
import 'package:scanserve/features/customer_menu/screens/order_success_screen.dart';
import 'package:scanserve/features/customer_menu/screens/public_menu_screen.dart';
import 'package:scanserve/features/landing/screens/landing_screen.dart';
import 'package:scanserve/features/restaurant_admin/screens/categories_screen.dart';
import 'package:scanserve/features/restaurant_admin/screens/menu_item_form_screen.dart';
import 'package:scanserve/features/restaurant_admin/screens/menu_screen.dart';
import 'package:scanserve/features/restaurant_admin/screens/order_detail_screen.dart';
import 'package:scanserve/features/restaurant_admin/screens/orders_screen.dart';
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

/// Notifies GoRouter when authState changes without disposing/re-creating the GoRouter instance.
class RouterNotifier extends ChangeNotifier {
  final Ref _ref;

  RouterNotifier(this._ref) {
    _ref.listen<AuthState>(
      authProvider,
      (_, __) => notifyListeners(),
    );
  }
}

final routerNotifierProvider = Provider<RouterNotifier>((ref) {
  return RouterNotifier(ref);
});

final appRouterProvider = Provider<GoRouter>((ref) {
  final notifier = ref.watch(routerNotifierProvider);

  return GoRouter(
    refreshListenable: notifier,
    redirect: (context, state) {
      final authState = ref.read(authProvider);

      return _redirect(
        authState,
        state.matchedLocation,
      );
    },
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
      // Customer-facing (Phase 5 & 6) - deliberately outside both admin
      // ShellRoutes: no admin nav chrome, and _redirect below never
      // treats these as protected, so they work with no auth at all.
      GoRoute(
        path: AppRoutes.customerMenuTemplate,
        name: 'customer-menu',
        builder: (context, state) {
          final slug = state.pathParameters['restaurantSlug']!;
          return PublicMenuScreen(restaurantSlug: slug);
        },
      ),
      GoRoute(
        path: AppRoutes.cart,
        name: 'cart',
        builder: (context, state) => const CartScreen(),
      ),
      GoRoute(
        path: AppRoutes.orderReview,
        name: 'order-review',
        builder: (context, state) => const OrderReviewScreen(),
      ),
      GoRoute(
        path: AppRoutes.orderSuccessTemplate,
        name: 'order-success',
        builder: (context, state) => OrderSuccessScreen(
          orderRef: state.pathParameters['orderRef']!,
        ),
      ),
      ShellRoute(
        builder: (context, state, child) =>
            RestaurantAdminScaffold(child: child),
        routes: [
          GoRoute(
            path: AppRoutes.dashboard,
            name: 'dashboard',
            builder: (context, state) => const RestaurantAdminDashboardScreen(),
          ),
          GoRoute(
            path: AppRoutes.dashboardOrders,
            name: 'dashboard-orders',
            builder: (context, state) => const OrdersScreen(),
          ),
          GoRoute(
            path: AppRoutes.dashboardOrderDetailTemplate,
            name: 'dashboard-order-detail',
            builder: (context, state) => OrderDetailScreen(
              orderId: state.pathParameters['id']!,
            ),
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
            builder: (context, state) => MenuItemFormScreen(
              menuItemId: state.pathParameters['id']!,
            ),
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
            builder: (context, state) => RestaurantDetailScreen(
              restaurantId: state.pathParameters['id']!,
            ),
          ),
          GoRoute(
            path: AppRoutes.superAdminRestaurantQrTemplate,
            name: 'super-admin-restaurant-qr',
            builder: (context, state) => RestaurantQrScreen(
              restaurantId: state.pathParameters['id']!,
            ),
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
  final homeForRole =
      user.isSuperAdmin ? AppRoutes.superAdminDashboard : AppRoutes.dashboard;

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
