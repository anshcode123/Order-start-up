import 'package:flutter/material.dart';
import 'package:scanserve/core/theme/app_colors.dart';
import 'package:scanserve/core/theme/app_text_styles.dart';
import 'package:scanserve/shared/widgets/app_logo.dart';
import 'package:scanserve/shared/widgets/section_container.dart';

class LandingFooter extends StatelessWidget {
  const LandingFooter({super.key});

  @override
  Widget build(BuildContext context) {
    return SectionContainer(
      verticalPadding: 32,
      child: Column(
        children: [
          const Divider(color: AppColors.border),
          const SizedBox(height: 20),
          const AppLogo(fontSize: 18),
          const SizedBox(height: 8),
          Text(
            '© ${DateTime.now().year} ScanServe. All rights reserved.',
            style: AppTextStyles.bodySmall.copyWith(color: AppColors.textMuted),
          ),
        ],
      ),
    );
  }
}
