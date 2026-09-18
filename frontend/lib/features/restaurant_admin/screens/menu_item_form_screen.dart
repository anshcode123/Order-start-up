import 'dart:typed_data';

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

/// Combined Add/Edit Menu Item form (Phase 4 spec #8, #13).
/// `menuItemId == null` means "create"; otherwise the form is prefilled
/// from GET /api/restaurant/menu-items/:id and submits a PUT.
class MenuItemFormScreen extends ConsumerStatefulWidget {
  const MenuItemFormScreen({super.key, this.menuItemId});

  final String? menuItemId;

  bool get isEditing => menuItemId != null;

  @override
  ConsumerState<MenuItemFormScreen> createState() => _MenuItemFormScreenState();
}

class _MenuItemFormScreenState extends ConsumerState<MenuItemFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _priceController = TextEditingController();

  String? _categoryId;
  bool _isAvailable = true;
  String? _existingImageUrl;
  XFile? _pickedImage;
  Uint8List? _pickedImageBytes;

  bool _hydrated = false;
  bool _isSubmitting = false;
  String? _errorMessage;

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  void _hydrate(MenuItem item) {
    if (_hydrated) return;
    _nameController.text = item.name;
    _descriptionController.text = item.description;
    _priceController.text = item.price;
    _categoryId = item.categoryId;
    _isAvailable = item.isAvailable;
    _existingImageUrl = item.imageUrl;
    _hydrated = true;
  }

  Future<void> _pickImage() async {
    final file = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (file == null) return;
    final bytes = await file.readAsBytes();
    setState(() {
      _pickedImage = file;
      _pickedImageBytes = bytes;
    });
  }

  /// Uploads the newly picked image (if any) and returns its URL.
  /// Returns the untouched existing URL if nothing new was picked -
  /// this is what stops a save from ever wiping out a working image
  /// because of an unrelated field edit (Phase 4 spec #13).
  Future<String?> _resolveImageUrl(Dio dio) async {
    if (_pickedImage == null) return _existingImageUrl;

    final bytes = _pickedImageBytes!;
    final formData = FormData.fromMap({
      'image': MultipartFile.fromBytes(bytes, filename: _pickedImage!.name),
    });

    // If this throws, the caller aborts the whole save - the existing
    // image (and the rest of the item) is never touched.
    final response = await dio.post('/restaurant/menu-items/upload-image', data: formData);
    return response.data['data']['url'] as String;
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_categoryId == null) {
      setState(() => _errorMessage = 'Please select a category');
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      final dio = ref.read(dioProvider);
      final imageUrl = await _resolveImageUrl(dio);

      final payload = {
        'name': _nameController.text.trim(),
        'description': _descriptionController.text.trim(),
        'price': _priceController.text.trim(),
        'categoryId': _categoryId,
        'imageUrl': imageUrl,
        'isAvailable': _isAvailable,
      };

      if (widget.isEditing) {
        await dio.put('/restaurant/menu-items/${widget.menuItemId}', data: payload);
      } else {
        await dio.post('/restaurant/menu-items', data: payload);
      }

      ref.invalidate(menuItemsProvider);
      ref.invalidate(restaurantAdminStatsProvider);
      if (widget.isEditing) ref.invalidate(menuItemProvider(widget.menuItemId!));

      if (mounted) {
        showSuccessSnackBar(context, widget.isEditing ? 'Menu item updated' : 'Menu item added');
        context.go(AppRoutes.dashboardMenu);
      }
    } catch (error) {
      setState(() => _errorMessage = apiErrorMessage(error));
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final categoriesAsync = ref.watch(categoriesProvider);
    final itemAsync = widget.isEditing
        ? ref.watch(menuItemProvider(widget.menuItemId!))
        : null;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SingleChildScrollView(
        padding: EdgeInsets.all(Responsive.pagePadding(context)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: (widget.isEditing && itemAsync != null)
              ? itemAsync.when(
                  loading: () => const Padding(
                    padding: EdgeInsets.symmetric(vertical: 60),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                  error: (error, _) => Text(
                    apiErrorMessage(error),
                    style: AppTextStyles.body.copyWith(color: AppColors.error),
                  ),
                  data: (item) {
                    _hydrate(item);
                    return _buildForm(categoriesAsync.valueOrNull ?? const []);
                  },
                )
              : _buildForm(categoriesAsync.valueOrNull ?? const []),
        ),
      ),
    );
  }

  Widget _buildForm(List<Category> categories) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(widget.isEditing ? 'Edit Menu Item' : 'Add Menu Item', style: AppTextStyles.displayMedium),
          const SizedBox(height: 24),
          if (_errorMessage != null) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.error.withOpacity(0.08),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.error.withOpacity(0.3)),
              ),
              child: Text(_errorMessage!, style: AppTextStyles.bodySmall.copyWith(color: AppColors.error)),
            ),
            const SizedBox(height: 20),
          ],
          _label('Food Name *'),
          TextFormField(
            controller: _nameController,
            validator: (v) => (v == null || v.trim().isEmpty) ? 'Food name is required' : null,
          ),
          const SizedBox(height: 16),
          _label('Description'),
          TextFormField(controller: _descriptionController, maxLines: 3),
          const SizedBox(height: 16),
          _label('Category *'),
          DropdownButtonFormField<String>(
            value: categories.any((c) => c.id == _categoryId) ? _categoryId : null,
            hint: const Text('Select a category'),
            items: [
              for (final category in categories)
                DropdownMenuItem(value: category.id, child: Text(category.name)),
            ],
            onChanged: (value) => setState(() => _categoryId = value),
          ),
          if (categories.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                'Create a category first before adding menu items.',
                style: AppTextStyles.bodySmall.copyWith(color: AppColors.textMuted),
              ),
            ),
          const SizedBox(height: 16),
          _label('Price *'),
          TextFormField(
            controller: _priceController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            validator: (v) {
              if (v == null || v.trim().isEmpty) return 'Price is required';
              final parsed = double.tryParse(v.trim());
              if (parsed == null) return 'Enter a valid number';
              if (parsed < 0) return 'Price must be 0 or greater';
              return null;
            },
          ),
          const SizedBox(height: 16),
          _label('Food Image'),
          _buildImagePicker(),
          const SizedBox(height: 16),
          Row(
            children: [
              Switch(value: _isAvailable, onChanged: (v) => setState(() => _isAvailable = v)),
              Text(_isAvailable ? 'Available' : 'Unavailable', style: AppTextStyles.bodySmall),
            ],
          ),
          const SizedBox(height: 28),
          AppPrimaryButton(
            label: _isSubmitting ? 'Saving...' : (widget.isEditing ? 'Save Changes' : 'Add Item'),
            expand: true,
            onPressed: _isSubmitting ? null : _submit,
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildImagePicker() {
    final preview = _pickedImageBytes != null
        ? Image.memory(_pickedImageBytes!, width: 96, height: 96, fit: BoxFit.cover)
        : (_existingImageUrl != null
            ? Image.network(_existingImageUrl!, width: 96, height: 96, fit: BoxFit.cover)
            : Container(
                width: 96,
                height: 96,
                color: AppColors.primaryLight,
                child: const Icon(Icons.image_outlined, color: AppColors.primaryDark),
              ));

    return Row(
      children: [
        ClipRRect(borderRadius: BorderRadius.circular(8), child: preview),
        const SizedBox(width: 16),
        OutlinedButton(onPressed: _pickImage, child: const Text('Choose Image')),
      ],
    );
  }

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(text, style: AppTextStyles.bodySmall.copyWith(
          color: AppColors.textPrimary,
          fontWeight: FontWeight.w500,
        )),
      );
}
