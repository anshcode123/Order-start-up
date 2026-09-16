import 'package:flutter/material.dart';
import 'package:scanserve/core/theme/app_colors.dart';
import 'package:scanserve/core/theme/app_text_styles.dart';
import 'package:scanserve/core/utils/responsive.dart';
import 'package:scanserve/shared/widgets/section_container.dart';

class _Step {
  const _Step(this.number, this.title, this.description);
  final String number;
  final String title;
  final String description;
}

const _steps = [
  _Step('1', 'Place your QR',
      'Print a unique QR code for each table and set it out.'),
  _Step('2', 'Customer scans',
      'The menu opens instantly in their browser - no app to install.'),
  _Step('3', 'Order & serve',
      'Orders land with your staff in real time, ready to prepare.'),
];

class HowItWorksSection extends StatelessWidget {
  const HowItWorksSection({super.key});

  @override
  Widget build(BuildContext context) {
    final isMobile = Responsive.isMobile(context);

    return SectionContainer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const Text('How It Works', style: AppTextStyles.displayMedium),
          const SizedBox(height: 40),
          Flex(
            direction: isMobile ? Axis.vertical : Axis.horizontal,
            children: [
              for (final step in _steps)
                Expanded(
                  flex: isMobile ? 0 : 1,
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: isMobile ? 0 : 16,
                      vertical: isMobile ? 16 : 0,
                    ),
                    child: _StepCard(step: step),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StepCard extends StatelessWidget {
  const _StepCard({required this.step});

  final _Step step;

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
          Container(
            width: 36,
            height: 36,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              color: AppColors.primaryLight,
              shape: BoxShape.circle,
            ),
            child: Text(
              step.number,
              style: AppTextStyles.title.copyWith(color: AppColors.primaryDark),
            ),
          ),
          const SizedBox(height: 16),
          Text(step.title, style: AppTextStyles.title),
          const SizedBox(height: 8),
          Text(step.description, style: AppTextStyles.bodySmall),
        ],
      ),
    );
  }
}
