import 'package:flutter/widgets.dart';

/// Breakpoints used across ScanServe so every screen agrees on what
/// counts as mobile / tablet / desktop.
class Responsive {
  Responsive._();

  static const double mobileMax = 600;
  static const double tabletMax = 1024;

  static bool isMobile(BuildContext context) =>
      MediaQuery.sizeOf(context).width < mobileMax;

  static bool isTablet(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    return width >= mobileMax && width < tabletMax;
  }

  static bool isDesktop(BuildContext context) =>
      MediaQuery.sizeOf(context).width >= tabletMax;

  /// Horizontal page padding that grows with screen size.
  static double pagePadding(BuildContext context) {
    if (isDesktop(context)) return 80;
    if (isTablet(context)) return 40;
    return 20;
  }

  /// Caps content width on very large screens so text/sections don't
  /// stretch edge-to-edge on desktop.
  static double maxContentWidth(BuildContext context) => 1200;
}
