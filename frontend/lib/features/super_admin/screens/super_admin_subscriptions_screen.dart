import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:scanserve/core/network/api_exception.dart';
import 'package:scanserve/core/network/dio_client.dart';
import 'package:scanserve/core/theme/app_colors.dart';
import 'package:scanserve/core/theme/app_text_styles.dart';
import 'package:scanserve/core/utils/responsive.dart';
import 'package:scanserve/features/super_admin/providers/subscription_providers.dart';
import 'package:scanserve/features/super_admin/widgets/stat_card.dart';
import 'package:scanserve/shared/models/subscription.dart';
import 'package:scanserve/shared/widgets/app_button.dart';
import 'package:scanserve/shared/widgets/app_dialogs.dart';
import 'package:scanserve/shared/widgets/subscription_status_badge.dart';

class SuperAdminSubscriptionsScreen extends ConsumerStatefulWidget {
  const SuperAdminSubscriptionsScreen({super.key});

  @override
  ConsumerState<SuperAdminSubscriptionsScreen> createState() =>
      _SuperAdminSubscriptionsScreenState();
}

class _SuperAdminSubscriptionsScreenState
    extends ConsumerState<SuperAdminSubscriptionsScreen> {
  String _statusFilter = '';

  String _formatDate(DateTime? dt) {
    if (dt == null) return '-';
    return dt.toLocal().toString().split(' ').first;
  }

  Future<void> _openManageModal(
    BuildContext context,
    RestaurantSubscription sub,
    List<SubscriptionPlan> plans,
  ) async {
    String selectedPlanId = sub.plan.id;
    String selectedStatus = sub.status;
    DateTime? selectedEndDate = sub.endDate ?? DateTime.now().add(const Duration(days: 30));
    final notesCtrl = TextEditingController(text: sub.notes ?? '');

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        bool saving = false;
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text('Manage Subscription — ${sub.restaurantName ?? sub.restaurantId}'),
              content: SizedBox(
                width: 460,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      DropdownButtonFormField<String>(
                        initialValue: plans.any((p) => p.id == selectedPlanId)
                            ? selectedPlanId
                            : (plans.isNotEmpty ? plans.first.id : null),
                        decoration: const InputDecoration(labelText: 'Subscription Plan'),
                        items: [
                          for (final plan in plans)
                            DropdownMenuItem(
                              value: plan.id,
                              child: Text('${plan.name} (₹${plan.priceMonthly}/mo)'),
                            ),
                        ],
                        onChanged: (v) {
                          if (v != null) setDialogState(() => selectedPlanId = v);
                        },
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        initialValue: selectedStatus,
                        decoration: const InputDecoration(labelText: 'Subscription Status'),
                        items: const [
                          DropdownMenuItem(value: 'TRIAL', child: Text('TRIAL')),
                          DropdownMenuItem(value: 'ACTIVE', child: Text('ACTIVE')),
                          DropdownMenuItem(value: 'EXPIRED', child: Text('EXPIRED')),
                          DropdownMenuItem(value: 'SUSPENDED', child: Text('SUSPENDED')),
                          DropdownMenuItem(value: 'CANCELLED', child: Text('CANCELLED')),
                        ],
                        onChanged: (v) {
                          if (v != null) setDialogState(() => selectedStatus = v);
                        },
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'End Date: ${_formatDate(selectedEndDate)}',
                            style: AppTextStyles.bodySmall,
                          ),
                          TextButton.icon(
                            icon: const Icon(Icons.calendar_today, size: 16),
                            label: const Text('Extend +30 Days'),
                            onPressed: () {
                              setDialogState(() {
                                final base = (selectedEndDate != null &&
                                        selectedEndDate!.isAfter(DateTime.now()))
                                    ? selectedEndDate!
                                    : DateTime.now();
                                selectedEndDate = base.add(const Duration(days: 30));
                                selectedStatus = 'ACTIVE';
                              });
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: notesCtrl,
                        maxLines: 2,
                        decoration: const InputDecoration(
                          labelText: 'Admin Notes',
                        ),
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
                            await dio.patch(
                              '/super-admin/restaurants/${sub.restaurantId}/subscription',
                              data: {
                                'planId': selectedPlanId,
                                'status': selectedStatus,
                                'endDate': selectedEndDate?.toUtc().toIso8601String(),
                                'notes': notesCtrl.text.trim(),
                              },
                            );
                            ref.invalidate(superAdminSubscriptionsProvider(_statusFilter));
                            ref.invalidate(superAdminRestaurantSubscriptionProvider(sub.restaurantId));
                            if (dialogContext.mounted) Navigator.of(dialogContext).pop();
                            if (context.mounted) {
                              showSuccessSnackBar(context, 'Subscription updated');
                            }
                          } catch (error) {
                            setDialogState(() => saving = false);
                            if (context.mounted) {
                              showErrorSnackBar(context, apiErrorMessage(error));
                            }
                          }
                        },
                  child: Text(saving ? 'Saving...' : 'Save Changes'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final subsAsync = ref.watch(superAdminSubscriptionsProvider(_statusFilter));
    final plansAsync = ref.watch(subscriptionPlansProvider);
    final plans = plansAsync.valueOrNull ?? const [];
    final isMobile = Responsive.isMobile(context);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(superAdminSubscriptionsProvider(_statusFilter)),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.all(Responsive.pagePadding(context)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Restaurant Subscriptions', style: AppTextStyles.displayMedium),
              const SizedBox(height: 4),
              Text(
                'Monitor trial periods, active plans, and billing status across all restaurants',
                style: AppTextStyles.bodySmall.copyWith(color: AppColors.textMuted),
              ),
              const SizedBox(height: 24),
              subsAsync.when(
                loading: () => const Padding(
                  padding: EdgeInsets.symmetric(vertical: 80),
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (error, _) => Text(
                  apiErrorMessage(error),
                  style: AppTextStyles.body.copyWith(color: AppColors.error),
                ),
                data: (data) => Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    GridView(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: isMobile ? 2 : 5,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                        childAspectRatio: isMobile ? 1.5 : 1.6,
                      ),
                      children: [
                        StatCard(
                          label: 'Active',
                          value: data.summary.activeSubscriptions,
                          accentColor: AppColors.success,
                        ),
                        StatCard(
                          label: 'Trial',
                          value: data.summary.trialSubscriptions,
                          accentColor: Colors.blue.shade700,
                        ),
                        StatCard(
                          label: 'Expired',
                          value: data.summary.expiredSubscriptions,
                          accentColor: Colors.orange.shade800,
                        ),
                        StatCard(
                          label: 'Suspended',
                          value: data.summary.suspendedSubscriptions,
                          accentColor: AppColors.error,
                        ),
                        StatCard(
                          label: 'Cancelled',
                          value: data.summary.cancelledSubscriptions,
                          accentColor: AppColors.textMuted,
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final status in ['', 'ACTIVE', 'TRIAL', 'EXPIRED', 'SUSPENDED', 'CANCELLED'])
                          ChoiceChip(
                            label: Text(status.isEmpty ? 'All' : status),
                            selected: _statusFilter == status,
                            onSelected: (_) => setState(() => _statusFilter = status),
                          ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Container(
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Column(
                        children: [
                          for (int i = 0; i < data.subscriptions.length; i++) ...[
                            if (i > 0) const Divider(height: 1, color: AppColors.border),
                            ListTile(
                              contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                              title: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      data.subscriptions[i].restaurantName ?? 'Restaurant',
                                      style: AppTextStyles.title.copyWith(fontSize: 15),
                                    ),
                                  ),
                                  SubscriptionStatusBadge(status: data.subscriptions[i].status),
                                ],
                              ),
                              subtitle: Padding(
                                padding: const EdgeInsets.only(top: 6),
                                child: Text(
                                  'Plan: ${data.subscriptions[i].plan.name}  •  Start: ${_formatDate(data.subscriptions[i].startDate)}  •  End: ${_formatDate(data.subscriptions[i].endDate ?? data.subscriptions[i].trialEndsAt)}',
                                  style: AppTextStyles.bodySmall.copyWith(color: AppColors.textMuted),
                                ),
                              ),
                              trailing: AppOutlinedButton(
                                label: 'Manage',
                                onPressed: () => _openManageModal(context, data.subscriptions[i], plans),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
