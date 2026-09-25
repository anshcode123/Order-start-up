import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:scanserve/core/network/api_exception.dart';
import 'package:scanserve/core/network/dio_client.dart';
import 'package:scanserve/core/theme/app_colors.dart';
import 'package:scanserve/core/theme/app_text_styles.dart';
import 'package:scanserve/core/utils/responsive.dart';
import 'package:scanserve/features/super_admin/providers/subscription_providers.dart';
import 'package:scanserve/shared/models/subscription.dart';
import 'package:scanserve/shared/widgets/app_button.dart';
import 'package:scanserve/shared/widgets/app_dialogs.dart';
import 'package:scanserve/shared/widgets/status_badge.dart';

class SuperAdminPlansScreen extends ConsumerWidget {
  const SuperAdminPlansScreen({super.key});

  Future<void> _showPlanDialog(BuildContext context, WidgetRef ref, {SubscriptionPlan? existing}) async {
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    final priceCtrl = TextEditingController(text: existing?.priceMonthly ?? '0');
    final maxCatCtrl = TextEditingController(
      text: existing?.maxCategories != null ? existing!.maxCategories.toString() : '',
    );
    final maxItemsCtrl = TextEditingController(
      text: existing?.maxMenuItems != null ? existing!.maxMenuItems.toString() : '',
    );
    bool whatsappEnabled = existing?.whatsappEnabled ?? true;
    bool analyticsEnabled = existing?.analyticsEnabled ?? false;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        bool saving = false;
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(existing == null ? 'Create Subscription Plan' : 'Edit ${existing.name} Plan'),
              content: SizedBox(
                width: 440,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextField(
                        controller: nameCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Plan Name (e.g. FREE, BASIC, PRO)',
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: priceCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Monthly Price (₹)',
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: maxCatCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Max Categories (leave empty for Unlimited)',
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: maxItemsCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Max Menu Items (leave empty for Unlimited)',
                        ),
                      ),
                      const SizedBox(height: 12),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('WhatsApp Notifications Enabled'),
                        value: whatsappEnabled,
                        onChanged: (v) => setDialogState(() => whatsappEnabled = v),
                      ),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Analytics Enabled'),
                        value: analyticsEnabled,
                        onChanged: (v) => setDialogState(() => analyticsEnabled = v),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: saving ? null : () => Navigator.of(dialogContext).pop(),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: saving
                      ? null
                      : () async {
                          setDialogState(() => saving = true);
                          try {
                            final dio = ref.read(dioProvider);
                            final maxCatText = maxCatCtrl.text.trim();
                            final maxItemsText = maxItemsCtrl.text.trim();
                            final payload = {
                              'name': nameCtrl.text.trim(),
                              'priceMonthly': double.tryParse(priceCtrl.text.trim()) ?? 0,
                              'maxCategories': maxCatText.isEmpty ? null : int.parse(maxCatText),
                              'maxMenuItems': maxItemsText.isEmpty ? null : int.parse(maxItemsText),
                              'whatsappEnabled': whatsappEnabled,
                              'analyticsEnabled': analyticsEnabled,
                            };
                            if (existing == null) {
                              await dio.post('/super-admin/plans', data: payload);
                            } else {
                              await dio.put('/super-admin/plans/${existing.id}', data: payload);
                            }
                            ref.invalidate(subscriptionPlansProvider);
                            if (dialogContext.mounted) Navigator.of(dialogContext).pop();
                            if (context.mounted) {
                              showSuccessSnackBar(
                                context,
                                existing == null ? 'Plan created' : 'Plan updated',
                              );
                            }
                          } catch (error) {
                            setDialogState(() => saving = false);
                            if (context.mounted) {
                              showErrorSnackBar(context, apiErrorMessage(error));
                            }
                          }
                        },
                  child: Text(saving ? 'Saving...' : 'Save Plan'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _toggleStatus(BuildContext context, WidgetRef ref, SubscriptionPlan plan) async {
    try {
      final dio = ref.read(dioProvider);
      await dio.patch('/super-admin/plans/${plan.id}/status', data: {
        'isActive': !plan.isActive,
      });
      ref.invalidate(subscriptionPlansProvider);
      if (context.mounted) {
        showSuccessSnackBar(
          context,
          !plan.isActive ? 'Plan activated' : 'Plan deactivated',
        );
      }
    } catch (error) {
      if (context.mounted) showErrorSnackBar(context, apiErrorMessage(error));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final plansAsync = ref.watch(subscriptionPlansProvider);
    final isMobile = Responsive.isMobile(context);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(subscriptionPlansProvider),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.all(Responsive.pagePadding(context)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Subscription Plans', style: AppTextStyles.displayMedium),
                        const SizedBox(height: 4),
                        Text(
                          'Configure SaaS tiers, menu limits, and feature entitlements',
                          style: AppTextStyles.bodySmall.copyWith(color: AppColors.textMuted),
                        ),
                      ],
                    ),
                  ),
                  AppPrimaryButton(
                    label: 'Create Plan',
                    onPressed: () => _showPlanDialog(context, ref),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              plansAsync.when(
                loading: () => const Padding(
                  padding: EdgeInsets.symmetric(vertical: 80),
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (error, _) => Text(
                  apiErrorMessage(error),
                  style: AppTextStyles.body.copyWith(color: AppColors.error),
                ),
                data: (plans) => GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: isMobile ? 1 : 3,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                    childAspectRatio: isMobile ? 1.35 : 1.15,
                  ),
                  itemCount: plans.length,
                  itemBuilder: (context, index) {
                    final plan = plans[index];
                    return Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(plan.name, style: AppTextStyles.title.copyWith(fontSize: 18)),
                              StatusBadge(isActive: plan.isActive),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '₹${plan.priceMonthly} / month',
                            style: AppTextStyles.displayMedium.copyWith(
                              fontSize: 22,
                              color: AppColors.primaryDark,
                            ),
                          ),
                          const Divider(height: 24),
                          _FeatureRow(
                            label: 'Max Categories',
                            value: plan.maxCategories?.toString() ?? 'Unlimited',
                          ),
                          _FeatureRow(
                            label: 'Max Menu Items',
                            value: plan.maxMenuItems?.toString() ?? 'Unlimited',
                          ),
                          _FeatureRow(
                            label: 'WhatsApp Orders',
                            value: plan.whatsappEnabled ? 'Included' : 'Disabled',
                          ),
                          _FeatureRow(
                            label: 'Analytics',
                            value: plan.analyticsEnabled ? 'Included' : 'Basic',
                          ),
                          const Spacer(),
                          Row(
                            children: [
                              Expanded(
                                child: AppOutlinedButton(
                                  label: 'Edit',
                                  onPressed: () => _showPlanDialog(context, ref, existing: plan),
                                ),
                              ),
                              const SizedBox(width: 8),
                              TextButton(
                                onPressed: () => _toggleStatus(context, ref, plan),
                                child: Text(plan.isActive ? 'Deactivate' : 'Activate'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FeatureRow extends StatelessWidget {
  const _FeatureRow({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: AppTextStyles.bodySmall.copyWith(color: AppColors.textMuted)),
          Text(
            value,
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
