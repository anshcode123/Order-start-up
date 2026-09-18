import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:scanserve/core/theme/app_colors.dart';
import 'package:scanserve/core/theme/app_text_styles.dart';
import 'package:scanserve/core/utils/responsive.dart';
import 'package:scanserve/features/auth/providers/auth_provider.dart';

/// Phase 4 spec only calls for a Settings nav entry, without detailing
/// what it should contain - this is a minimal read-only placeholder
/// (account + restaurant info) so the nav link isn't dead. Real settings
/// (password change, restaurant profile editing, etc.) are a later
/// phase's job.
class RestaurantAdminSettingsScreen extends ConsumerWidget {
  const RestaurantAdminSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider).user;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SingleChildScrollView(
        padding: EdgeInsets.all(Responsive.pagePadding(context)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Settings', style: AppTextStyles.displayMedium),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _row('Restaurant', user?.restaurantName ?? '-'),
                    _row('Admin Name', user?.name ?? '-'),
                    _row('Admin Email', user?.email ?? '-'),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Password changes and restaurant profile editing will be '
                'added in a later phase.',
                style: AppTextStyles.bodySmall.copyWith(color: AppColors.textMuted),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          SizedBox(width: 120, child: Text(label, style: AppTextStyles.bodySmall.copyWith(color: AppColors.textMuted))),
          Expanded(child: Text(value, style: AppTextStyles.bodySmall.copyWith(color: AppColors.textPrimary))),
        ],
      ),
    );
  }
}
