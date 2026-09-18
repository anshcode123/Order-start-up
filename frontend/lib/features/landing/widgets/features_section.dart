import 'package:flutter/material.dart';
import 'package:scanserve/core/theme/app_colors.dart';
import 'package:scanserve/core/theme/app_text_styles.dart';
import 'package:scanserve/core/utils/responsive.dart';
import 'package:scanserve/shared/widgets/section_container.dart';

class _Feature {
  const _Feature(this.icon, this.title, this.description);
  final IconData icon;
  final String title;
  final String description;
}

const _features = [
  _Feature(Icons.qr_code_2_rounded, 'Instant QR Menus', 'Generate a scannable menu for every table in seconds.'),
  _Feature(Icons.restaurant_menu_rounded, 'Live Menu Editing', 'Update dishes, prices, and availability without reprinting anything.'),
  _Feature(Icons.table_bar_rounded, 'Table Ordering', 'Customers order directly from their phone at the table.'),
  _Feature(Icons.devices_rounded, 'Works Everywhere', 'A responsive experience across desktop, tablet, and mobile.'),
];

class FeaturesSection extends StatelessWidget {
  const FeaturesSection({super.key});

  @override
  Widget build(BuildContext context) {
    final columns = Responsive.isDesktop(context)
        ? 4
        : Responsive.isTablet(context)
            ? 2
            : 1;

    return SectionContainer(
      backgroundColor: AppColors.background,
      child: Column(
        children: [
          Text('Features', style: AppTextStyles.displayMedium),
          const SizedBox(height: 40),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _features.length,
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: columns,
              mainAxisSpacing: 20,
              crossAxisSpacing: 20,
              childAspectRatio: columns == 1 ? 2.4 : 1.1,
            ),
            itemBuilder: (context, index) => _FeatureCard(feature: _features[index]),
          ),
        ],
      ),
    );
  }
}

class _FeatureCard extends StatelessWidget {
  const _FeatureCard({required this.feature});

  final _Feature feature;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(feature.icon, color: AppColors.primary, size: 28),
          const SizedBox(height: 16),
          Text(feature.title, style: AppTextStyles.title),
          const SizedBox(height: 8),
          Text(feature.description, style: AppTextStyles.bodySmall),
        ],
      ),
    );
  }
}
