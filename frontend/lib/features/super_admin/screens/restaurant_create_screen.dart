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

/// POST /api/admin/restaurants form, followed by an inline success view.
/// Per spec: restaurant details + admin details in one form, one submit,
/// and the admin password is never shown back after creation.
class RestaurantCreateScreen extends ConsumerStatefulWidget {
  const RestaurantCreateScreen({super.key});

  @override
  ConsumerState<RestaurantCreateScreen> createState() =>
      _RestaurantCreateScreenState();
}

class _RestaurantCreateScreenState
    extends ConsumerState<RestaurantCreateScreen> {
  final _formKey = GlobalKey<FormState>();

  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _addressController = TextEditingController();

  final _adminNameController = TextEditingController();
  final _adminEmailController = TextEditingController();
  final _adminPasswordController = TextEditingController();

  bool _isSubmitting = false;
  String? _errorMessage;
  CreatedRestaurantResult? _created;

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _addressController.dispose();
    _adminNameController.dispose();
    _adminEmailController.dispose();
    _adminPasswordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      final dio = ref.read(dioProvider);
      final response = await dio.post('/admin/restaurants', data: {
        'restaurant': {
          'name': _nameController.text.trim(),
          'description': _descriptionController.text.trim(),
          'phone': _phoneController.text.trim(),
          'email': _emailController.text.trim(),
          'address': _addressController.text.trim(),
        },
        'admin': {
          'name': _adminNameController.text.trim(),
          'email': _adminEmailController.text.trim(),
          'password': _adminPasswordController.text,
        },
      });

      ref.invalidate(restaurantsListProvider);
      ref.invalidate(superAdminDashboardProvider);

      setState(() {
        _created = CreatedRestaurantResult.fromJson(
            response.data as Map<String, dynamic>);
      });
    } catch (error) {
      setState(() => _errorMessage = apiErrorMessage(error));
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_created != null) {
      return _CreateSuccessView(result: _created!);
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SingleChildScrollView(
        padding: EdgeInsets.all(Responsive.pagePadding(context)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Create Restaurant', style: AppTextStyles.displayMedium),
                const SizedBox(height: 24),
                if (_errorMessage != null) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.error.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                          color: AppColors.error.withValues(alpha: 0.3)),
                    ),
                    child: Text(
                      _errorMessage!,
                      style: AppTextStyles.bodySmall
                          .copyWith(color: AppColors.error),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
                _SectionHeading('RESTAURANT DETAILS'),
                const SizedBox(height: 16),
                _LabeledField(
                  label: 'Restaurant Name *',
                  controller: _nameController,
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'Restaurant name is required'
                      : null,
                ),
                _LabeledField(
                    label: 'Description',
                    controller: _descriptionController,
                    maxLines: 3),
                _LabeledField(
                    label: 'Phone',
                    controller: _phoneController,
                    keyboardType: TextInputType.phone),
                _LabeledField(
                  label: 'Email',
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return null; // optional
                    return v.contains('@') ? null : 'Enter a valid email';
                  },
                ),
                _LabeledField(
                    label: 'Address',
                    controller: _addressController,
                    maxLines: 2),
                const SizedBox(height: 24),
                _SectionHeading('RESTAURANT ADMIN'),
                const SizedBox(height: 16),
                _LabeledField(
                  label: 'Admin Name *',
                  controller: _adminNameController,
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'Admin name is required'
                      : null,
                ),
                _LabeledField(
                  label: 'Admin Email *',
                  controller: _adminEmailController,
                  keyboardType: TextInputType.emailAddress,
                  validator: (v) {
                    if (v == null || v.trim().isEmpty)
                      return 'Admin email is required';
                    return v.contains('@') ? null : 'Enter a valid email';
                  },
                ),
                _LabeledField(
                  label: 'Admin Password *',
                  controller: _adminPasswordController,
                  obscureText: true,
                  validator: (v) {
                    if (v == null || v.isEmpty)
                      return 'Admin password is required';
                    if (v.length < 8)
                      return 'Password must be at least 8 characters';
                    return null;
                  },
                ),
                const SizedBox(height: 28),
                AppPrimaryButton(
                  label: _isSubmitting ? 'Creating...' : 'CREATE RESTAURANT',
                  expand: true,
                  onPressed: _isSubmitting ? null : _submit,
                ),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CreateSuccessView extends StatelessWidget {
  const _CreateSuccessView({required this.result});

  final CreatedRestaurantResult result;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.check_circle_rounded,
                      color: AppColors.success, size: 40),
                  const SizedBox(height: 16),
                  Text('Restaurant Created Successfully',
                      style: AppTextStyles.headline),
                  const SizedBox(height: 24),
                  _Row('Restaurant', result.restaurantName),
                  _Row('Admin', result.adminEmail),
                  _Row('Menu URL', result.menuUrl),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: AppOutlinedButton(
                          label: 'View QR',
                          expand: true,
                          onPressed: () => context.go(
                              AppRoutes.superAdminRestaurantQr(
                                  result.restaurantId)),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: AppPrimaryButton(
                          label: 'Done',
                          expand: true,
                          onPressed: () =>
                              context.go(AppRoutes.superAdminRestaurants),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
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
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style:
                  AppTextStyles.bodySmall.copyWith(color: AppColors.textMuted)),
          Text(value,
              style: AppTextStyles.bodySmall
                  .copyWith(color: AppColors.textPrimary)),
        ],
      ),
    );
  }
}

class _SectionHeading extends StatelessWidget {
  const _SectionHeading(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: AppTextStyles.bodySmall.copyWith(
        color: AppColors.textMuted,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.6,
      ),
    );
  }
}

class _LabeledField extends StatelessWidget {
  const _LabeledField({
    required this.label,
    required this.controller,
    this.validator,
    this.obscureText = false,
    this.maxLines = 1,
    this.keyboardType,
  });

  final String label;
  final TextEditingController controller;
  final String? Function(String?)? validator;
  final bool obscureText;
  final int maxLines;
  final TextInputType? keyboardType;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w500,
              )),
          const SizedBox(height: 6),
          TextFormField(
            controller: controller,
            validator: validator,
            obscureText: obscureText,
            maxLines: obscureText ? 1 : maxLines,
            keyboardType: keyboardType,
          ),
        ],
      ),
    );
  }
}
