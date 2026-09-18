import 'package:flutter/material.dart';
import 'package:scanserve/core/theme/app_colors.dart';
import 'package:scanserve/core/theme/app_text_styles.dart';
import 'package:scanserve/shared/widgets/section_container.dart';

class _Faq {
  const _Faq(this.question, this.answer);
  final String question;
  final String answer;
}

const _faqs = [
  _Faq('Do customers need to download an app?', 'No. Scanning the QR opens the menu directly in their phone\'s browser.'),
  _Faq('Can I update my menu myself?', 'Yes, menu changes are made from your restaurant dashboard and go live immediately.'),
  _Faq('How do I get an account?', 'Accounts are issued by the platform administrator - reach out to get set up.'),
];

class FaqSection extends StatelessWidget {
  const FaqSection({super.key});

  @override
  Widget build(BuildContext context) {
    return SectionContainer(
      backgroundColor: AppColors.background,
      child: Column(
        children: [
          Text('FAQ', style: AppTextStyles.displayMedium),
          const SizedBox(height: 32),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: Column(
              children: [for (final faq in _faqs) _FaqTile(faq: faq)],
            ),
          ),
        ],
      ),
    );
  }
}

class _FaqTile extends StatelessWidget {
  const _FaqTile({required this.faq});

  final _Faq faq;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: ExpansionTile(
        shape: const RoundedRectangleBorder(side: BorderSide.none),
        collapsedShape: const RoundedRectangleBorder(side: BorderSide.none),
        title: Text(faq.question, style: AppTextStyles.title.copyWith(fontSize: 16)),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        expandedCrossAxisAlignment: CrossAxisAlignment.start,
        children: [Text(faq.answer, style: AppTextStyles.bodySmall)],
      ),
    );
  }
}
