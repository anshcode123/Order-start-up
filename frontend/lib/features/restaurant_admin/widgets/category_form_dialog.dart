import 'package:flutter/material.dart';
import 'package:scanserve/core/theme/app_colors.dart';
import 'package:scanserve/core/theme/app_text_styles.dart';
import 'package:scanserve/shared/widgets/app_button.dart';

/// Result returned when the dialog is saved: {name, description}.
/// Null means the user cancelled.
Future<({String name, String description})?> showCategoryFormDialog(
  BuildContext context, {
  String? initialName,
  String? initialDescription,
}) {
  return showDialog<({String name, String description})>(
    context: context,
    builder: (context) => _CategoryFormDialog(
      initialName: initialName,
      initialDescription: initialDescription,
    ),
  );
}

class _CategoryFormDialog extends StatefulWidget {
  const _CategoryFormDialog({this.initialName, this.initialDescription});

  final String? initialName;
  final String? initialDescription;

  @override
  State<_CategoryFormDialog> createState() => _CategoryFormDialogState();
}

class _CategoryFormDialogState extends State<_CategoryFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final _nameController = TextEditingController(text: widget.initialName ?? '');
  late final _descriptionController = TextEditingController(text: widget.initialDescription ?? '');

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  void _save() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    Navigator.of(context).pop((
      name: _nameController.text.trim(),
      description: _descriptionController.text.trim(),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.initialName != null;

    return AlertDialog(
      title: Text(isEditing ? 'Edit Category' : 'Add Category'),
      content: Form(
        key: _formKey,
        child: SizedBox(
          width: 360,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Category Name *', style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w500,
              )),
              const SizedBox(height: 6),
              TextFormField(
                controller: _nameController,
                autofocus: true,
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Category name is required' : null,
                onFieldSubmitted: (_) => _save(),
              ),
              const SizedBox(height: 16),
              Text('Description', style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w500,
              )),
              const SizedBox(height: 6),
              TextFormField(controller: _descriptionController, maxLines: 2),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        AppPrimaryButton(label: 'Save', onPressed: _save),
      ],
    );
  }
}
