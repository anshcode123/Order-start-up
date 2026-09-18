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

  // Added in a later phase - do not implement yet:
  // static const String customerMenu = '/menu/:slug';
}
