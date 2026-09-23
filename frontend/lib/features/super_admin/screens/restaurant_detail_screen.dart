import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:scanserve/core/constants/app_routes.dart';
import 'package:scanserve/core/network/api_exception.dart';
import 'package:scanserve/core/network/dio_client.dart';
import 'package:scanserve/core/theme/app_colors.dart';
import 'package:scanserve/core/theme/app_text_styles.dart';
import 'package:scanserve/core/utils/responsive.dart';
import 'package:scanserve/features/super_admin/providers/restaurant_providers.dart';
import 'package:scanserve/shared/models/restaurant.dart';
import 'package:scanserve/shared/widgets/app_button.dart';
import 'package:scanserve/shared/widgets/app_dialogs.dart';
import 'package:scanserve/shared/widgets/status_badge.dart';

/// Doubles as both "View" and "Edit" from the restaurants list - the
/// fields are editable inline with a single Save action, per
/// PUT /api/admin/restaurants/:id. Slug is shown but read-only here on
/// purpose: the backend won't change it just because the name changes,
/// to avoid breaking QR codes already handed out.
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

  bool _hydrated = false;
  bool _isSaving = false;

  void _hydrate(Restaurant restaurant) {
    if (_hydrated) return;
    _nameController.text = restaurant.name;
    _descriptionController.text = restaurant.description ?? '';
    _phoneController.text = restaurant.phone ?? '';
    _emailController.text = restaurant.email ?? '';
    _addressController.text = restaurant.address ?? '';
    _hydrated = true;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _addressController.dispose();
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
      });
      ref.invalidate(restaurantDetailProvider(widget.restaurantId));
      ref.invalidate(restaurantsListProvider);
      if (mounted) showSuccessSnackBar(context, 'Restaurant updated');
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
      title: activating ? 'Enable restaurant?' : 'Disable restaurant?',
      message: activating
          ? '${restaurant.name} will become active again.'
          : '${restaurant.name} will be marked inactive. This does not delete any data.',
      confirmLabel: activating ? 'Enable' : 'Disable',
    );
    if (!confirmed) return;

    try {
      final dio = ref.read(dioProvider);
      await dio.patch('/admin/restaurants/${restaurant.id}/status', data: {
        'status': activating ? 'ACTIVE' : 'INACTIVE',
      });
      ref.invalidate(restaurantDetailProvider(widget.restaurantId));
      ref.invalidate(restaurantsListProvider);
      if (mounted)
        showSuccessSnackBar(
            context, activating ? 'Restaurant enabled' : 'Restaurant disabled');
    } catch (error) {
      if (mounted) showErrorSnackBar(context, apiErrorMessage(error));
    }
  }

  @override
  Widget build(BuildContext context) {
    final detailAsync =
        ref.watch(restaurantDetailProvider(widget.restaurantId));

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SingleChildScrollView(
        padding: EdgeInsets.all(Responsive.pagePadding(context)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: detailAsync.when(
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: 60),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (error, _) => Text(
              apiErrorMessage(error),
              style: AppTextStyles.body.copyWith(color: AppColors.error),
            ),
            data: (detail) {
              _hydrate(detail.restaurant);
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                          child: Text(detail.restaurant.name,
                              style: AppTextStyles.displayMedium)),
                      StatusBadge(isActive: detail.restaurant.isActive),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text('/${detail.restaurant.slug}',
                      style: AppTextStyles.bodySmall
                          .copyWith(color: AppColors.textMuted)),
                  const SizedBox(height: 24),
                  _InfoCard(
                    title: 'Restaurant Admin',
                    children: [
                      _Row('Name', detail.admin?.name ?? '-'),
                      _Row('Email', detail.admin?.email ?? '-'),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _InfoCard(
                    title: 'Menu URL',
                    trailing: TextButton(
                      onPressed: () => context.go(
                          AppRoutes.superAdminRestaurantQr(
                              widget.restaurantId)),
                      child: const Text('View QR'),
                    ),
                    children: [
                      Text(detail.menuUrl,
                          style: AppTextStyles.bodySmall
                              .copyWith(color: AppColors.textPrimary)),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Text('EDIT DETAILS',
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.textMuted,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.6,
                      )),
                  const SizedBox(height: 16),
                  _Field('Restaurant Name', _nameController),
                  _Field('Description', _descriptionController, maxLines: 3),
                  _Field('Phone', _phoneController),
                  _Field('Email', _emailController),
                  _Field('Address', _addressController, maxLines: 2),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: AppPrimaryButton(
                          label: _isSaving ? 'Saving...' : 'Save Changes',
                          expand: true,
                          onPressed: _isSaving ? null : _save,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: AppOutlinedButton(
                          label:
                              detail.restaurant.isActive ? 'Disable' : 'Enable',
                          expand: true,
                          onPressed: () => _toggleStatus(detail.restaurant),
                        ),
                      ),
                    ],
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
                      style: AppTextStyles.title.copyWith(fontSize: 15))),
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
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        children: [
          SizedBox(
              width: 70,
              child: Text(label,
                  style: AppTextStyles.bodySmall
                      .copyWith(color: AppColors.textMuted))),
          Expanded(
              child: Text(value,
                  style: AppTextStyles.bodySmall
                      .copyWith(color: AppColors.textPrimary))),
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
          Text(label,
              style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.textPrimary, fontWeight: FontWeight.w500)),
          const SizedBox(height: 6),
          TextFormField(controller: controller, maxLines: maxLines),
        ],
      ),
    );
  }
}
