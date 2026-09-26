import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:scanserve/core/constants/app_routes.dart';
import 'package:scanserve/core/network/api_exception.dart';
import 'package:scanserve/core/network/dio_client.dart';
import 'package:scanserve/core/theme/app_colors.dart';
import 'package:scanserve/core/theme/app_text_styles.dart';
import 'package:scanserve/core/utils/responsive.dart';
import 'package:scanserve/features/restaurant_admin/providers/menu_providers.dart';
import 'package:scanserve/shared/models/category.dart';
import 'package:scanserve/shared/models/menu_item.dart';
import 'package:scanserve/shared/widgets/app_button.dart';
import 'package:scanserve/shared/widgets/app_dialogs.dart';

class MenuItemFormScreen extends ConsumerStatefulWidget {
  const MenuItemFormScreen({super.key, this.menuItemId});

  final String? menuItemId;

  bool get isEdit => menuItemId != null;

  @override
  ConsumerState<MenuItemFormScreen> createState() => _MenuItemFormScreenState();
}

class _MenuItemFormScreenState extends ConsumerState<MenuItemFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _priceController = TextEditingController();
  final _halfPriceController = TextEditingController();
  final _fullPriceController = TextEditingController();

  String? _selectedCategoryId;
  String? _imageUrl;
  bool _isAvailable = true;
  bool _hasVariants = false;
  bool _halfEnabled = true;
  bool _fullEnabled = true;
  bool _halfAvailable = true;
  bool _fullAvailable = true;

  bool _hydrated = false;
  bool _isUploadingImage = false;
  bool _isSaving = false;

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    _halfPriceController.dispose();
    _fullPriceController.dispose();
    super.dispose();
  }

  String? _validatePrice(String? value) {
    if (value == null || value.trim().isEmpty) return 'Price is required';
    final parsed = double.tryParse(value.trim());
    if (parsed == null) return 'Enter a valid number';
    if (parsed < 0) return 'Price must be 0 or greater';
    return null;
  }

  void _hydrateFrom(MenuItem item) {
    if (_hydrated) return;
    _nameController.text = item.name;
    _descriptionController.text = item.description;
    _priceController.text = item.price;
    _selectedCategoryId = item.categoryId;
    _imageUrl = item.imageUrl;
    _isAvailable = item.isAvailable;
    _hasVariants = item.hasVariants;

    if (item.hasVariants && item.variants.isNotEmpty) {
      final half = item.variants.where((v) => v.name.toLowerCase() == 'half').firstOrNull;
      final full = item.variants.where((v) => v.name.toLowerCase() == 'full').firstOrNull;
      _halfEnabled = half != null;
      if (half != null) {
        _halfPriceController.text = half.price;
        _halfAvailable = half.isAvailable;
      }
      _fullEnabled = full != null;
      if (full != null) {
        _fullPriceController.text = full.price;
        _fullAvailable = full.isAvailable;
      }
    }
    _hydrated = true;
  }

  Future<void> _pickAndUploadImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery);
    if (picked == null) return;

    setState(() => _isUploadingImage = true);
    try {
      final bytes = await picked.readAsBytes();
      final formData = FormData.fromMap({
        'image': MultipartFile.fromBytes(bytes, filename: picked.name),
      });

      final dio = ref.read(dioProvider);
      final response = await dio.post('/restaurant/menu-items/upload-image', data: formData);
      final dataMap = response.data['data'] as Map<String, dynamic>?;
      final uploadedUrl = (dataMap?['url'] ?? dataMap?['imageUrl']) as String?;
      if (mounted && uploadedUrl != null) {
        setState(() => _imageUrl = uploadedUrl);
      }
    } catch (error) {
      if (mounted) showErrorSnackBar(context, apiErrorMessage(error));
    } finally {
      if (mounted) setState(() => _isUploadingImage = false);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedCategoryId == null) {
      showErrorSnackBar(context, 'Please select a category.');
      return;
    }

    final variantsPayload = <Map<String, dynamic>>[];
    if (_hasVariants) {
      if (!_halfEnabled && !_fullEnabled) {
        showErrorSnackBar(context, 'Please enable at least Half or Full variant.');
        return;
      }
      if (_halfEnabled) {
        final err = _validatePrice(_halfPriceController.text);
        if (err != null) {
          showErrorSnackBar(context, 'Half variant: $err');
          return;
        }
        variantsPayload.add({
          'name': 'Half',
          'price': _halfPriceController.text.trim(),
          'isAvailable': _halfAvailable,
        });
      }
      if (_fullEnabled) {
        final err = _validatePrice(_fullPriceController.text);
        if (err != null) {
          showErrorSnackBar(context, 'Full variant: $err');
          return;
        }
        variantsPayload.add({
          'name': 'Full',
          'price': _fullPriceController.text.trim(),
          'isAvailable': _fullAvailable,
        });
      }
    }

    setState(() => _isSaving = true);
    try {
      final dio = ref.read(dioProvider);
      final payload = <String, dynamic>{
        'name': _nameController.text.trim(),
        'description': _descriptionController.text.trim(),
        'categoryId': _selectedCategoryId,
        'imageUrl': _imageUrl,
        'isAvailable': _isAvailable,
        'hasVariants': _hasVariants,
        if (_hasVariants)
          'variants': variantsPayload
        else
          'price': _priceController.text.trim(),
      };

      if (widget.isEdit) {
        await dio.put('/restaurant/menu-items/${widget.menuItemId}', data: payload);
      } else {
        await dio.post('/restaurant/menu-items', data: payload);
      }

      ref.invalidate(menuItemsProvider);
      ref.invalidate(restaurantAdminStatsProvider);
      if (widget.isEdit) {
        ref.invalidate(menuItemProvider(widget.menuItemId!));
      }

      if (mounted) {
        showSuccessSnackBar(
          context,
          widget.isEdit ? 'Menu item updated' : 'Menu item created',
        );
        context.go(AppRoutes.dashboardMenu);
      }
    } catch (error) {
      if (mounted) showErrorSnackBar(context, apiErrorMessage(error));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final categoriesAsync = ref.watch(categoriesProvider);

    if (widget.isEdit) {
      final detailAsync = ref.watch(menuItemProvider(widget.menuItemId!));
      return detailAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Text(
            apiErrorMessage(error),
            style: AppTextStyles.body.copyWith(color: AppColors.error),
          ),
        ),
        data: (item) {
          _hydrateFrom(item);
          return _buildForm(context, categoriesAsync);
        },
      );
    }

    return _buildForm(context, categoriesAsync);
  }

  Widget _buildForm(BuildContext context, AsyncValue<List<Category>> categoriesAsync) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SingleChildScrollView(
        padding: EdgeInsets.all(Responsive.pagePadding(context)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.isEdit ? 'Edit Menu Item' : 'Add Menu Item',
                  style: AppTextStyles.displayMedium,
                ),
                const SizedBox(height: 24),
                _label('Food Name *'),
                TextFormField(
                  controller: _nameController,
                  validator: (value) => (value == null || value.trim().isEmpty)
                      ? 'Food name is required'
                      : null,
                ),
                const SizedBox(height: 16),
                _label('Description (optional)'),
                TextFormField(
                  controller: _descriptionController,
                  maxLines: 3,
                ),
                const SizedBox(height: 16),

                // Half / Full Variant Toggle Card
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                          'Enable Half / Full Portions',
                          style: AppTextStyles.bodySmall.copyWith(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        subtitle: Text(
                          _hasVariants
                              ? 'Customers will choose Half or Full before adding to cart.'
                              : 'Single standard price for this dish.',
                          style: AppTextStyles.bodySmall.copyWith(color: AppColors.textMuted),
                        ),
                        value: _hasVariants,
                        onChanged: (v) => setState(() => _hasVariants = v),
                      ),
                      const SizedBox(height: 12),
                      if (!_hasVariants) ...[
                        _label('Price (₹) *'),
                        TextFormField(
                          controller: _priceController,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          validator: (val) => _hasVariants ? null : _validatePrice(val),
                        ),
                      ] else ...[
                        _buildVariantEditorRow(
                          title: 'Half Portion',
                          enabled: _halfEnabled,
                          onEnabledChanged: (val) => setState(() => _halfEnabled = val ?? false),
                          priceController: _halfPriceController,
                          available: _halfAvailable,
                          onAvailableChanged: (val) => setState(() => _halfAvailable = val),
                        ),
                        const Divider(height: 24, color: AppColors.border),
                        _buildVariantEditorRow(
                          title: 'Full Portion',
                          enabled: _fullEnabled,
                          onEnabledChanged: (val) => setState(() => _fullEnabled = val ?? false),
                          priceController: _fullPriceController,
                          available: _fullAvailable,
                          onAvailableChanged: (val) => setState(() => _fullAvailable = val),
                        ),
                      ],
                    ],
                  ),
                ),

                const SizedBox(height: 16),
                _label('Category *'),
                categoriesAsync.when(
                  loading: () => const LinearProgressIndicator(),
                  error: (error, _) => Text(
                    apiErrorMessage(error),
                    style: AppTextStyles.bodySmall.copyWith(color: AppColors.error),
                  ),
                  data: (categories) {
                    if (categories.isEmpty) {
                      return Text(
                        'Create a category first before adding menu items.',
                        style: AppTextStyles.bodySmall.copyWith(color: AppColors.error),
                      );
                    }
                    return DropdownButtonFormField<String>(
                      initialValue: categories.any((c) => c.id == _selectedCategoryId)
                          ? _selectedCategoryId
                          : null,
                      hint: const Text('Select category'),
                      items: [
                        for (final c in categories)
                          DropdownMenuItem(value: c.id, child: Text(c.name)),
                      ],
                      onChanged: (value) => setState(() => _selectedCategoryId = value),
                    );
                  },
                ),
                const SizedBox(height: 20),
                _label('Image (optional)'),
                Row(
                  children: [
                    if (_imageUrl != null) ...[
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(
                          _imageUrl!,
                          width: 72,
                          height: 72,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => const SizedBox(width: 72, height: 72),
                        ),
                      ),
                      const SizedBox(width: 12),
                    ],
                    OutlinedButton.icon(
                      onPressed: _isUploadingImage ? null : _pickAndUploadImage,
                      icon: _isUploadingImage
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.upload_outlined, size: 18),
                      label: Text(_imageUrl == null ? 'Upload Image' : 'Change Image'),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Available on customer menu'),
                  value: _isAvailable,
                  onChanged: (value) => setState(() => _isAvailable = value),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    AppPrimaryButton(
                      label: _isSaving
                          ? 'Saving...'
                          : (widget.isEdit ? 'Save Changes' : 'Create Item'),
                      onPressed: (_isSaving || _isUploadingImage) ? null : _save,
                    ),
                    const SizedBox(width: 12),
                    TextButton(
                      onPressed: () => context.go(AppRoutes.dashboardMenu),
                      child: const Text('Cancel'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildVariantEditorRow({
    required String title,
    required bool enabled,
    required ValueChanged<bool?> onEnabledChanged,
    required TextEditingController priceController,
    required bool available,
    required ValueChanged<bool> onAvailableChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Checkbox(value: enabled, onChanged: onEnabledChanged),
            Expanded(
              child: Text(
                title,
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            if (enabled) ...[
              Text(
                available ? 'Available' : 'Unavailable',
                style: AppTextStyles.bodySmall.copyWith(
                  color: available ? AppColors.success : AppColors.textMuted,
                ),
              ),
              Switch(
                value: available,
                onChanged: onAvailableChanged,
              ),
            ],
          ],
        ),
        if (enabled)
          Padding(
            padding: const EdgeInsets.only(left: 12, top: 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _label('$title Price (₹) *'),
                TextFormField(
                  controller: priceController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(
          text,
          style: AppTextStyles.bodySmall.copyWith(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w500,
          ),
        ),
      );
}
