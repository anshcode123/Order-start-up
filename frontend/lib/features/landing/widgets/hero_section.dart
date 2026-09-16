import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:scanserve/core/constants/app_routes.dart';
import 'package:scanserve/core/constants/app_strings.dart';
import 'package:scanserve/core/theme/app_colors.dart';
import 'package:scanserve/core/theme/app_text_styles.dart';
import 'package:scanserve/core/utils/responsive.dart';
import 'package:scanserve/shared/widgets/app_button.dart';
import 'package:scanserve/shared/widgets/section_container.dart';

/// Primary hero banner: headline, subtitle, and the two main CTAs.
class HeroSection extends StatelessWidget {
  const HeroSection({super.key});

  @override
  Widget build(BuildContext context) {
    final isMobile = Responsive.isMobile(context);
    final titleStyle = isMobile
        ? AppTextStyles.displayMedium
        : AppTextStyles.displayLarge;

    return SectionContainer(
      verticalPadding: isMobile ? 56 : 96,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            AppStrings.heroTitle,
            textAlign: TextAlign.center,
            style: titleStyle,
          ),
          const SizedBox(height: 20),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Text(
              AppStrings.heroSubtitle,
              textAlign: TextAlign.center,
              style: AppTextStyles.body.copyWith(color: AppColors.textSecondary),
            ),
          ),
          const SizedBox(height: 32),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 16,
            runSpacing: 16,
            children: [
              AppPrimaryButton(
                label: AppStrings.restaurantLogin,
                onPressed: () => context.go(AppRoutes.login),
              ),
              AppOutlinedButton(
                label: AppStrings.viewDemo,
                onPressed: () {},
              ),
            ],
          ),
        ],
      ),
    );
  }
}
