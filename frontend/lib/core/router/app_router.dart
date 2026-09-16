import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:scanserve/core/constants/app_routes.dart';
import 'package:scanserve/features/auth/providers/auth_provider.dart';
import 'package:scanserve/features/auth/screens/login_screen.dart';
import 'package:scanserve/features/landing/screens/landing_screen.dart';
import 'package:scanserve/features/restaurant_dashboard/screens/restaurant_dashboard_screen.dart';
import 'package:scanserve/features/super_admin/screens/super_admin_screen.dart';

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
    initialLocation: AppRoutes.landing,
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
      GoRoute(
        path: AppRoutes.superAdmin,
        name: 'super-admin',
        builder: (context, state) => const SuperAdminScreen(),
      ),
      GoRoute(
        path: AppRoutes.dashboard,
        name: 'dashboard',
        builder: (context, state) => const RestaurantDashboardScreen(),
      ),
    ],
    redirect: (context, state) {
      final authState = ref.read(authProvider);

      // Wait until session is checked on app startup
      if (!authState.isInitialized) {
        return null;
      }

      final isLoggingIn = state.matchedLocation == AppRoutes.login;
      final isSuperAdminRoute = state.matchedLocation == AppRoutes.superAdmin;
      final isDashboardRoute = state.matchedLocation == AppRoutes.dashboard;

      final isAuthenticated = authState.isAuthenticated;
      final user = authState.user;

      // Unauthenticated user trying to access protected routes
      if (!isAuthenticated) {
        if (isSuperAdminRoute || isDashboardRoute) {
          return AppRoutes.login;
        }
        return null;
      }

      // Authenticated user
      if (user?.isSuperAdmin == true) {
        if (isLoggingIn || isDashboardRoute) {
          return AppRoutes.superAdmin;
        }
      } else if (user?.isRestaurantAdmin == true) {
        if (isLoggingIn || isSuperAdminRoute) {
          return AppRoutes.dashboard;
        }
      }

      return null;
    },
  );
});
