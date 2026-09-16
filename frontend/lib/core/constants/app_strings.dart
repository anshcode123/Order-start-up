/// Static copy used across the app. Keeping marketing/UI copy here
/// makes it easy to update wording without hunting through widgets.
class AppStrings {
  AppStrings._();

  static const String brand = 'ScanServe';

  // Landing - hero
  static const String heroTitle = 'Your Menu.\nOne Scan Away.';
  static const String heroSubtitle =
      'Customers scan your QR, browse your menu, and order straight from '
      'their table.';

  // Landing - nav
  static const String navHowItWorks = 'How It Works';
  static const String navFeatures = 'Features';
  static const String restaurantLogin = 'Restaurant Login';
  static const String viewDemo = 'View Demo';

  // Login
  static const String welcomeBack = 'Welcome back';
  static const String loginSubtitle =
      'Restaurant and platform administrators only.';
  static const String email = 'Email';
  static const String password = 'Password';
  static const String logIn = 'Log in';
  static const String loginFooter =
      'Accounts are issued by the platform administrator. Contact them if '
      'you need access.';
}
