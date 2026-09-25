import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:scanserve/core/network/api_exception.dart';
import 'package:scanserve/core/network/dio_client.dart';
import 'package:scanserve/core/theme/app_colors.dart';
import 'package:scanserve/core/theme/app_text_styles.dart';
import 'package:scanserve/core/utils/responsive.dart';
import 'package:scanserve/features/auth/providers/auth_provider.dart';
import 'package:scanserve/features/restaurant_admin/providers/menu_providers.dart';
import 'package:scanserve/shared/widgets/app_button.dart';
import 'package:scanserve/shared/widgets/app_dialogs.dart';

class RestaurantAdminSettingsScreen extends ConsumerStatefulWidget {
  const RestaurantAdminSettingsScreen({super.key});

  @override
  ConsumerState<RestaurantAdminSettingsScreen> createState() =>
      _RestaurantAdminSettingsScreenState();
}

class _RestaurantAdminSettingsScreenState
    extends ConsumerState<RestaurantAdminSettingsScreen> {
  final _formKey = GlobalKey<FormState>();

  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _phoneController = TextEditingController();
  final _whatsAppController = TextEditingController();
  final _emailController = TextEditingController();
  final _addressController = TextEditingController();

  String? _slug;
  String? _logoUrl;
  bool _isActive = true;
  bool _hydrated = false;
  bool _isSaving = false;
  bool _isUploadingLogo = false;

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _phoneController.dispose();
    _whatsAppController.dispose();
    _emailController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  void _hydrate(Map<String, dynamic> settings) {
    if (_hydrated) return;
    _nameController.text = (settings['name'] as String?) ?? '';
    _descriptionController.text = (settings['description'] as String?) ?? '';
    _phoneController.text = (settings['phone'] as String?) ?? '';
    _whatsAppController.text = (settings['whatsappNumber'] as String?) ?? '';
    _emailController.text = (settings['email'] as String?) ?? '';
    _addressController.text = (settings['address'] as String?) ?? '';
    _slug = settings['slug'] as String?;
    _logoUrl = settings['logoUrl'] as String?;
    _isActive = (settings['isActive'] as bool?) ?? true;
    _hydrated = true;
  }

  Future<void> _pickAndUploadLogo() async {
    try {
      final file = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
      );
      if (file == null) return;

      setState(() => _isUploadingLogo = true);
      final bytes = await file.readAsBytes();
      final formData = FormData.fromMap({
        'logo': MultipartFile.fromBytes(bytes, filename: file.name),
      });

      final dio = ref.read(dioProvider);
      final response =
          await dio.post('/restaurant/settings/logo', data: formData);
      final newUrl = response.data['data']['logoUrl'] as String?;

      setState(() {
        _logoUrl = newUrl;
      });

      ref.invalidate(restaurantSettingsProvider);
      if (mounted) {
        showSuccessSnackBar(context, 'Logo uploaded successfully');
      }
    } catch (e) {
      if (mounted) {
        showErrorSnackBar(context, apiErrorMessage(e));
      }
    } finally {
      if (mounted) {
        setState(() => _isUploadingLogo = false);
      }
    }
  }

  Future<void> _removeLogo() async {
    setState(() => _logoUrl = null);
  }

  Future<void> _saveSettings() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);
    try {
      final dio = ref.read(dioProvider);
      await dio.put('/restaurant/settings', data: {
        'name': _nameController.text.trim(),
        'description': _descriptionController.text.trim(),
        'phone': _phoneController.text.trim(),
        'email': _emailController.text.trim(),
        'address': _addressController.text.trim(),
        'whatsappNumber': _whatsAppController.text.trim(),
        'logoUrl': _logoUrl,
        'isActive': _isActive,
      });

      ref.invalidate(restaurantSettingsProvider);
      if (mounted) {
        showSuccessSnackBar(context, 'Restaurant settings saved successfully');
      }
    } catch (e) {
      if (mounted) {
        showErrorSnackBar(context, apiErrorMessage(e));
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider).user;
    final settingsAsync = ref.watch(restaurantSettingsProvider);

    settingsAsync.whenData((data) => _hydrate(data));

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SingleChildScrollView(
        padding: EdgeInsets.all(Responsive.pagePadding(context)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: settingsAsync.when(
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: 80),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (err, _) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 40),
              child: Center(
                child: Text(
                  apiErrorMessage(err),
                  style: AppTextStyles.body.copyWith(color: AppColors.error),
                ),
              ),
            ),
            data: (_) => Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Restaurant Settings',
                      style: AppTextStyles.displayMedium),
                  const SizedBox(height: 8),
                  Text(
                    'Manage your restaurant profile, contact details, WhatsApp alerts, and menu visibility.',
                    style: AppTextStyles.bodySmall
                        .copyWith(color: AppColors.textMuted),
                  ),
                  const SizedBox(height: 24),

                  // Logo Card
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Restaurant Logo',
                            style: AppTextStyles.title),
                        const SizedBox(height: 8),
                        Text(
                          'Upload a square or brand logo to display on your public digital menu.',
                          style: AppTextStyles.bodySmall
                              .copyWith(color: AppColors.textMuted),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Container(
                              width: 80,
                              height: 80,
                              decoration: BoxDecoration(
                                color: AppColors.background,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: AppColors.border),
                              ),
                              child: _logoUrl != null && _logoUrl!.isNotEmpty
                                  ? ClipRRect(
                                      borderRadius: BorderRadius.circular(10),
                                      child: Image.network(
                                        _logoUrl!,
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, __, ___) =>
                                            const Icon(
                                          Icons.storefront_outlined,
                                          size: 36,
                                          color: AppColors.textMuted,
                                        ),
                                      ),
                                    )
                                  : const Icon(
                                      Icons.storefront_outlined,
                                      size: 36,
                                      color: AppColors.textMuted,
                                    ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Wrap(
                                spacing: 10,
                                runSpacing: 8,
                                children: [
                                  AppOutlinedButton(
                                    label: _isUploadingLogo
                                        ? 'Uploading...'
                                        : 'Change Logo',
                                    onPressed: _isUploadingLogo
                                        ? null
                                        : _pickAndUploadLogo,
                                  ),
                                  if (_logoUrl != null && _logoUrl!.isNotEmpty)
                                    AppOutlinedButton(
                                      label: 'Remove',
                                      onPressed:
                                          _isUploadingLogo ? null : _removeLogo,
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Profile Details Card
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Profile Information',
                            style: AppTextStyles.title),
                        const SizedBox(height: 16),
                        Text('Restaurant Name *', style: _labelStyle),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: _nameController,
                          decoration: const InputDecoration(
                            hintText: 'e.g. Bella Italia Bistro',
                            prefixIcon:
                                Icon(Icons.restaurant_outlined, size: 18),
                          ),
                          validator: (val) {
                            if (val == null || val.trim().isEmpty) {
                              return 'Restaurant name is required';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        Text('Menu URL Slug', style: _labelStyle),
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 10),
                          decoration: BoxDecoration(
                            color: AppColors.background,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.link,
                                  size: 16, color: AppColors.textMuted),
                              const SizedBox(width: 8),
                              Text(
                                _slug != null ? '/menu/$_slug' : '-',
                                style: AppTextStyles.bodySmall.copyWith(
                                  color: AppColors.textPrimary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text('Description', style: _labelStyle),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: _descriptionController,
                          maxLines: 3,
                          decoration: const InputDecoration(
                            hintText:
                                'Brief description of your restaurant, cuisine, or story...',
                          ),
                        ),
                        const SizedBox(height: 16),
                        Material(
                          color: Colors.transparent,
                          child: SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text('Store Status', style: _labelStyle),
                            subtitle: Text(
                              _isActive
                                  ? 'Active — Customers can view menu and place orders.'
                                  : 'Inactive — Menu is temporarily unavailable for orders.',
                              style: AppTextStyles.bodySmall
                                  .copyWith(color: AppColors.textMuted),
                            ),
                            value: _isActive,
                            onChanged: (val) => setState(() => _isActive = val),
                            activeThumbColor: AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Contact Details Card
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Contact & Location',
                            style: AppTextStyles.title),
                        const SizedBox(height: 16),
                        Text('Public Phone', style: _labelStyle),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: _phoneController,
                          keyboardType: TextInputType.phone,
                          decoration: const InputDecoration(
                            hintText: '+91XXXXXXXXXX or landline',
                            prefixIcon: Icon(Icons.phone_outlined, size: 18),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text('Contact Email', style: _labelStyle),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          decoration: const InputDecoration(
                            hintText: 'contact@yourrestaurant.com',
                            prefixIcon: Icon(Icons.email_outlined, size: 18),
                          ),
                          validator: (val) {
                            final trimmed = val?.trim() ?? '';
                            if (trimmed.isNotEmpty && !trimmed.contains('@')) {
                              return 'Enter a valid email address';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        Text('Physical Address', style: _labelStyle),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: _addressController,
                          maxLines: 2,
                          decoration: const InputDecoration(
                            hintText: '123 Food Street, Downtown...',
                            prefixIcon:
                                Icon(Icons.location_on_outlined, size: 18),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // WhatsApp Notifications Card
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.chat_bubble_outline,
                                color: AppColors.primary, size: 20),
                            SizedBox(width: 8),
                            Text('WhatsApp Order Notifications',
                                style: AppTextStyles.title),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Receive instant WhatsApp notifications with full order details whenever a customer places an order.',
                          style: AppTextStyles.bodySmall
                              .copyWith(color: AppColors.textMuted),
                        ),
                        const SizedBox(height: 16),
                        Text('WhatsApp Phone Number (E.164)',
                            style: _labelStyle),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: _whatsAppController,
                          keyboardType: TextInputType.phone,
                          decoration: const InputDecoration(
                            hintText: '+91XXXXXXXXXX',
                            prefixIcon:
                                Icon(Icons.phone_iphone_outlined, size: 18),
                          ),
                          validator: (value) {
                            final trimmed = value?.trim() ?? '';
                            if (trimmed.isEmpty) return null;
                            final digits =
                                trimmed.replaceAll(RegExp(r'\D'), '');
                            if (digits.length < 7 || digits.length > 15) {
                              return 'Enter a valid phone number with country code (e.g. +91XXXXXXXXXX)';
                            }
                            return null;
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Account Info (read-only)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Admin Account', style: AppTextStyles.title),
                        const SizedBox(height: 16),
                        _row('Admin Name', user?.name ?? '-'),
                        _row('Admin Email', user?.email ?? '-'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 28),

                  AppPrimaryButton(
                    label:
                        _isSaving ? 'Saving Changes...' : 'Save All Settings',
                    expand: true,
                    onPressed: _isSaving ? null : _saveSettings,
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  TextStyle get _labelStyle => AppTextStyles.bodySmall.copyWith(
        color: AppColors.textPrimary,
        fontWeight: FontWeight.w600,
      );

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          SizedBox(
            width: 120,
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
