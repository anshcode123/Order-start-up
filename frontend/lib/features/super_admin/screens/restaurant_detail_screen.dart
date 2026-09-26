import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:scanserve/core/constants/app_routes.dart';
import 'package:scanserve/core/network/api_exception.dart';
import 'package:scanserve/core/network/dio_client.dart';
import 'package:scanserve/core/theme/app_colors.dart';
import 'package:scanserve/core/theme/app_text_styles.dart';
import 'package:scanserve/core/utils/responsive.dart';
import 'package:scanserve/features/restaurant_admin/widgets/order_status_chip.dart';
import 'package:scanserve/features/super_admin/providers/restaurant_providers.dart';
import 'package:scanserve/features/super_admin/widgets/stat_card.dart';
import 'package:scanserve/shared/models/restaurant.dart';
import 'package:scanserve/shared/widgets/app_button.dart';
import 'package:scanserve/shared/widgets/app_dialogs.dart';
import 'package:scanserve/shared/widgets/status_badge.dart';

class RestaurantDetailScreen extends ConsumerStatefulWidget {
  const RestaurantDetailScreen({super.key, required this.restaurantId});

  final String restaurantId;

  @override
  ConsumerState<RestaurantDetailScreen> createState() =>
      _RestaurantDetailScreenState();
}

class _RestaurantDetailScreenState
    extends ConsumerState<RestaurantDetailScreen> {
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _addressController = TextEditingController();
  final _whatsappNumberController = TextEditingController();

  bool _hydrated = false;
  bool _isSaving = false;

  void _hydrate(Restaurant restaurant) {
    if (_hydrated) return;
    _nameController.text = restaurant.name;
    _descriptionController.text = restaurant.description ?? '';
    _phoneController.text = restaurant.phone ?? '';
    _emailController.text = restaurant.email ?? '';
    _addressController.text = restaurant.address ?? '';
    _whatsappNumberController.text = restaurant.whatsappNumber ?? '';
    _hydrated = true;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _addressController.dispose();
    _whatsappNumberController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _isSaving = true);
    try {
      final dio = ref.read(dioProvider);
      await dio.put('/admin/restaurants/${widget.restaurantId}', data: {
        'name': _nameController.text.trim(),
        'description': _descriptionController.text.trim(),
        'phone': _phoneController.text.trim(),
        'email': _emailController.text.trim(),
        'address': _addressController.text.trim(),
        'whatsappNumber': _whatsappNumberController.text.trim(),
      });
      ref.invalidate(restaurantDetailProvider(widget.restaurantId));
      ref.invalidate(restaurantsListProvider(''));
      if (mounted) {
        showSuccessSnackBar(context, 'Restaurant details updated successfully');
      }
    } catch (error) {
      if (mounted) showErrorSnackBar(context, apiErrorMessage(error));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _toggleStatus(Restaurant restaurant) async {
    final activating = !restaurant.isActive;
    final confirmed = await showConfirmDialog(
      context,
      title: activating ? 'Activate restaurant?' : 'Deactivate restaurant?',
      message: activating
          ? '${restaurant.name} will become active again and its customer menu will accept orders.'
          : '${restaurant.name} will be marked inactive. This does not delete any data.',
      confirmLabel: activating ? 'Activate' : 'Deactivate',
    );
    if (!confirmed) return;

    try {
      final dio = ref.read(dioProvider);
      await dio.patch('/admin/restaurants/${restaurant.id}/status', data: {
        'status': activating ? 'ACTIVE' : 'INACTIVE',
      });
      ref.invalidate(restaurantDetailProvider(widget.restaurantId));
      ref.invalidate(restaurantsListProvider(''));
      ref.invalidate(superAdminDashboardProvider);
      if (mounted) {
        showSuccessSnackBar(
          context,
          activating ? 'Restaurant activated' : 'Restaurant deactivated',
        );
      }
    } catch (error) {
      if (mounted) showErrorSnackBar(context, apiErrorMessage(error));
    }
  }

  @override
  Widget build(BuildContext context) {
    final detailAsync =
        ref.watch(restaurantDetailProvider(widget.restaurantId));
    final statsAsync = ref.watch(restaurantStatsProvider(widget.restaurantId));
    final isMobile = Responsive.isMobile(context);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SingleChildScrollView(
        padding: EdgeInsets.all(Responsive.pagePadding(context)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: detailAsync.when(
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: 80),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (error, _) => Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 40),
                child: Text(
                  apiErrorMessage(error),
                  style: AppTextStyles.body.copyWith(color: AppColors.error),
                ),
              ),
            ),
            data: (detail) {
              _hydrate(detail.restaurant);

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(detail.restaurant.name,
                                style: AppTextStyles.displayMedium),
                            const SizedBox(height: 4),
                            Text(
                              '/${detail.restaurant.slug}',
                              style: AppTextStyles.bodySmall.copyWith(
                                color: AppColors.primaryDark,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Row(
                        children: [
                          StatusBadge(isActive: detail.restaurant.isActive),
                          const SizedBox(width: 12),
                          AppOutlinedButton(
                            label: detail.restaurant.isActive
                                ? 'Deactivate'
                                : 'Activate',
                            onPressed: () => _toggleStatus(detail.restaurant),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Section 3: Usage Statistics
                  const Text('Usage Statistics', style: AppTextStyles.title),
                  const SizedBox(height: 12),
                  statsAsync.when(
                    loading: () => const Padding(
                      padding: EdgeInsets.symmetric(vertical: 24),
                      child: Center(child: CircularProgressIndicator()),
                    ),
                    error: (_, __) => Text(
                      'Could not load usage statistics.',
                      style: AppTextStyles.bodySmall
                          .copyWith(color: AppColors.textMuted),
                    ),
                    data: (stats) => Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        GridView(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          gridDelegate:
                              SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: isMobile ? 2 : 4,
                            mainAxisSpacing: 12,
                            crossAxisSpacing: 12,
                            childAspectRatio: isMobile ? 1.4 : 1.6,
                          ),
                          children: [
                            StatCard(
                              label: 'Total Orders',
                              value: stats.totalOrders,
                              icon: Icons.receipt_long_outlined,
                              accentColor: AppColors.primaryDark,
                            ),
                            StatCard(
                              label: "Today's Orders",
                              value: stats.todayOrders,
                              icon: Icons.today_outlined,
                              accentColor: Colors.blue.shade700,
                            ),
                            StatCard(
                              label: 'Pending Orders',
                              value: stats.pendingOrders,
                              icon: Icons.pending_actions_outlined,
                              accentColor: Colors.orange.shade800,
                            ),
                            StatCard(
                              label: 'Ready Orders',
                              value: stats.completedOrders,
                              icon: Icons.done_all_outlined,
                              accentColor: AppColors.success,
                            ),
                            StatCard(
                              label: 'Categories',
                              value: stats.totalCategories,
                              icon: Icons.category_outlined,
                              accentColor: AppColors.primary,
                            ),
                            StatCard(
                              label: 'Total Menu Items',
                              value: stats.totalMenuItems,
                              icon: Icons.restaurant_menu_outlined,
                              accentColor: AppColors.primary,
                            ),
                            StatCard(
                              label: 'Available Items',
                              value: stats.availableMenuItems,
                              icon: Icons.check_circle_outline,
                              accentColor: AppColors.success,
                            ),
                            StatCard(
                              label: 'Revenue',
                              value: 0,
                              displayValue: '₹${stats.totalRevenue}',
                              icon: Icons.payments_outlined,
                              accentColor: Colors.teal.shade700,
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // Order Status Breakdown pills
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Orders by Status',
                                  style: AppTextStyles.title
                                      .copyWith(fontSize: 14)),
                              const SizedBox(height: 12),
                              Wrap(
                                spacing: 10,
                                runSpacing: 8,
                                children: [
                                  for (final entry
                                      in stats.statusBreakdown.entries)
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 10, vertical: 6),
                                      decoration: BoxDecoration(
                                        color: AppColors.background,
                                        borderRadius: BorderRadius.circular(8),
                                        border:
                                            Border.all(color: AppColors.border),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          OrderStatusChip(status: entry.key),
                                          const SizedBox(width: 8),
                                          Text(
                                            '${entry.value}',
                                            style: AppTextStyles.bodySmall
                                                .copyWith(
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 28),

                  // Restaurant Information & QR Action
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: _InfoCard(
                          title: 'Admin Credentials',
                          children: [
                            _Row('Admin Name', detail.admin?.name ?? '-'),
                            _Row('Admin Email', detail.admin?.email ?? '-'),
                            if (detail.restaurant.createdAt != null)
                              _Row(
                                'Created Date',
                                detail.restaurant.createdAt!
                                    .toLocal()
                                    .toString()
                                    .split(' ')
                                    .first,
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _InfoCard(
                          title: 'Customer Menu & QR',
                          trailing: TextButton.icon(
                            icon: const Icon(Icons.qr_code, size: 16),
                            label: const Text('View QR'),
                            onPressed: () => context.go(
                              AppRoutes.superAdminRestaurantQr(
                                  widget.restaurantId),
                            ),
                          ),
                          children: [
                            Text(
                              detail.menuUrl,
                              style: AppTextStyles.bodySmall.copyWith(
                                color: AppColors.textPrimary,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 28),

                  // Edit Restaurant Information Form
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Edit Restaurant Details',
                            style: AppTextStyles.title),
                        const SizedBox(height: 16),
                        _Field('Restaurant Name', _nameController),
                        _Field('Description', _descriptionController,
                            maxLines: 3),
                        Row(
                          children: [
                            Expanded(
                                child:
                                    _Field('Public Phone', _phoneController)),
                            const SizedBox(width: 16),
                            Expanded(
                                child:
                                    _Field('Contact Email', _emailController)),
                          ],
                        ),
                        _Field('Address', _addressController, maxLines: 2),
                        _Field('WhatsApp Notification Number',
                            _whatsappNumberController),
                        const SizedBox(height: 12),
                        AppPrimaryButton(
                          label: _isSaving
                              ? 'Saving Changes...'
                              : 'Save Restaurant Details',
                          expand: true,
                          onPressed: _isSaving ? null : _save,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 40),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.title, required this.children, this.trailing});
  final String title;
  final List<Widget> children;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(title,
                    style: AppTextStyles.title.copyWith(fontSize: 15)),
              ),
              if (trailing != null) trailing!,
            ],
          ),
          const SizedBox(height: 8),
          ...children,
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row(this.label, this.value);
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style:
                  AppTextStyles.bodySmall.copyWith(color: AppColors.textMuted),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: AppTextStyles.bodySmall
                  .copyWith(color: AppColors.textPrimary),
            ),
          ),
        ],
      ),
    );
  }
}

class _Field extends StatelessWidget {
  const _Field(this.label, this.controller, {this.maxLines = 1});
  final String label;
  final TextEditingController controller;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 6),
          TextFormField(controller: controller, maxLines: maxLines),
        ],
      ),
    );
  }
}
