import 'package:flutter/material.dart';
import 'package:scanserve/core/theme/app_colors.dart';
import 'package:scanserve/core/theme/app_text_styles.dart';
import 'package:scanserve/core/utils/responsive.dart';
import 'package:scanserve/shared/widgets/app_button.dart';
import 'package:scanserve/shared/widgets/section_container.dart';

class _Plan {
  const _Plan(this.name, this.price, this.period, this.perks, {this.highlighted = false});
  final String name;
  final String price;
  final String period;
  final List<String> perks;
  final bool highlighted;
}

const _plans = [
  _Plan('Starter', '\$19', '/mo', ['1 restaurant', 'Up to 10 tables', 'QR menu & ordering']),
  _Plan('Growth', '\$49', '/mo', ['1 restaurant', 'Unlimited tables', 'Priority support'], highlighted: true),
  _Plan('Multi-Location', 'Custom', '', ['Multiple restaurants', 'Centralized admin', 'Dedicated onboarding']),
];

class PricingSection extends StatelessWidget {
  const PricingSection({super.key});

  @override
  Widget build(BuildContext context) {
    final isMobile = Responsive.isMobile(context);

    return SectionContainer(
      child: Column(
        children: [
          Text('Pricing', style: AppTextStyles.displayMedium),
          const SizedBox(height: 40),
          Flex(
            direction: isMobile ? Axis.vertical : Axis.horizontal,
            children: [
              for (final plan in _plans)
                Expanded(
                  flex: isMobile ? 0 : 1,
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: isMobile ? 0 : 12,
                      vertical: isMobile ? 12 : 0,
                    ),
                    child: _PlanCard(plan: plan),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PlanCard extends StatelessWidget {
  const _PlanCard({required this.plan});

  final _Plan plan;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: plan.highlighted ? AppColors.primaryLight : AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: plan.highlighted ? AppColors.primary : AppColors.border,
          width: plan.highlighted ? 1.5 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(plan.name, style: AppTextStyles.title),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(plan.price, style: AppTextStyles.displayMedium.copyWith(fontSize: 32)),
              if (plan.period.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(left: 4, bottom: 6),
                  child: Text(plan.period, style: AppTextStyles.bodySmall),
                ),
            ],
          ),
          const SizedBox(height: 20),
          for (final perk in plan.perks)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.check_circle_rounded, color: AppColors.primary, size: 18),
                  const SizedBox(width: 8),
                  Expanded(child: Text(perk, style: AppTextStyles.bodySmall)),
                ],
              ),
            ),
          const SizedBox(height: 12),
          AppOutlinedButton(label: 'View Demo', onPressed: () {}, expand: true),
        ],
      ),
    );
  }
}
