/// Central place for route path strings so screens never hardcode paths.
class AppRoutes {
  AppRoutes._();

  static const String landing = '/';
  static const String login = '/login';

  // Restaurant Admin
  static const String dashboard = '/dashboard';
  static const String dashboardCategories = '/dashboard/categories';
  static const String dashboardMenu = '/dashboard/menu';
  static const String dashboardMenuItemCreate = '/dashboard/menu/create';
  static String dashboardMenuItemEdit(String id) => '/dashboard/menu/$id/edit';
  static const String dashboardQr = '/dashboard/qr';
  static const String dashboardSettings = '/dashboard/settings';

  // Route templates (as registered with go_router, with :id placeholders)
  static const String dashboardMenuItemEditTemplate = '/dashboard/menu/:id/edit';

  // Super Admin
  static const String superAdminDashboard = '/super-admin';
  static const String superAdminRestaurants = '/super-admin/restaurants';
  static const String superAdminRestaurantCreate = '/super-admin/restaurants/create';
  static String superAdminRestaurantDetail(String id) => '/super-admin/restaurants/$id';
  static String superAdminRestaurantQr(String id) => '/super-admin/restaurants/$id/qr';

  // Route templates (as registered with go_router, with :id placeholders)
  static const String superAdminRestaurantDetailTemplate = '/super-admin/restaurants/:id';
  static const String superAdminRestaurantQrTemplate = '/super-admin/restaurants/:id/qr';

  // Customer-facing (Phase 5) - public, no auth
  static String customerMenu(String restaurantSlug) => '/menu/$restaurantSlug';
  static const String customerMenuTemplate = '/menu/:restaurantSlug';
  static const String cart = '/cart';
  static const String orderReview = '/order/review';

  // Customer-facing (Phase 6) - public, no auth. A distinct "success/"
  // segment keeps this from ever pattern-colliding with /order/review.
  static String orderSuccess(String orderRef) => '/order/success/$orderRef';
  static const String orderSuccessTemplate = '/order/success/:orderRef';

  // Restaurant Admin (Phase 6)
  static const String dashboardOrders = '/dashboard/orders';
  static String dashboardOrderDetail(String id) => '/dashboard/orders/$id';
  static const String dashboardOrderDetailTemplate = '/dashboard/orders/:id';
}
