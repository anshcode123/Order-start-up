import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:scanserve/core/constants/app_routes.dart';
import 'package:scanserve/core/constants/app_strings.dart';
import 'package:scanserve/core/theme/app_colors.dart';
import 'package:scanserve/core/theme/app_text_styles.dart';
import 'package:scanserve/core/utils/responsive.dart';
import 'package:scanserve/shared/widgets/app_button.dart';
import 'package:scanserve/shared/widgets/app_logo.dart';

/// Top navigation bar for the marketing landing page.
/// On mobile the nav links collapse and only the logo + login button show,
/// since the full nav doesn't fit a narrow viewport.
class LandingHeader extends StatelessWidget {
  const LandingHeader({super.key});

  @override
  Widget build(BuildContext context) {
    final isDesktop = Responsive.isDesktop(context);

    return Container(
      color: AppColors.surface,
      padding: EdgeInsets.symmetric(
        horizontal: Responsive.pagePadding(context),
        vertical: 18,
      ),
      child: Row(
        children: [
          const AppLogo(),
          const Spacer(),
          if (isDesktop) ...[
            _NavLink(label: AppStrings.navHowItWorks),
            const SizedBox(width: 32),
            _NavLink(label: AppStrings.navFeatures),
            const SizedBox(width: 32),
            _NavLink(label: AppStrings.navPricing),
            const SizedBox(width: 32),
            _NavLink(label: AppStrings.navFaq),
            const SizedBox(width: 40),
          ],
          AppOutlinedButton(
            label: AppStrings.restaurantLogin,
            onPressed: () => context.go(AppRoutes.login),
          ),
        ],
      ),
    );
  }
}

class _NavLink extends StatelessWidget {
  const _NavLink({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(label, style: AppTextStyles.bodySmall.copyWith(
      color: AppColors.textPrimary,
      fontWeight: FontWeight.w500,
    ));
  }
}
