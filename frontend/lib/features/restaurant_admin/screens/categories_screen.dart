import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:scanserve/core/network/api_exception.dart';
import 'package:scanserve/core/network/dio_client.dart';
import 'package:scanserve/core/theme/app_colors.dart';
import 'package:scanserve/core/theme/app_text_styles.dart';
import 'package:scanserve/core/utils/responsive.dart';
import 'package:scanserve/features/restaurant_admin/providers/menu_providers.dart';
import 'package:scanserve/features/restaurant_admin/widgets/category_form_dialog.dart';
import 'package:scanserve/shared/models/category.dart';
import 'package:scanserve/shared/widgets/app_dialogs.dart';

class CategoriesScreen extends ConsumerWidget {
  const CategoriesScreen({super.key});

  Future<void> _addCategory(BuildContext context, WidgetRef ref) async {
    final result = await showCategoryFormDialog(context);
    if (result == null) return;

    try {
      final dio = ref.read(dioProvider);
      await dio.post('/restaurant/categories', data: {
        'name': result.name,
        'description': result.description,
      });
      ref.invalidate(categoriesProvider);
      if (context.mounted) showSuccessSnackBar(context, 'Category created');
    } catch (error) {
      if (context.mounted) showErrorSnackBar(context, apiErrorMessage(error));
    }
  }

  Future<void> _editCategory(BuildContext context, WidgetRef ref, Category category) async {
    final result = await showCategoryFormDialog(
      context,
      initialName: category.name,
      initialDescription: category.description,
    );
    if (result == null) return;

    try {
      final dio = ref.read(dioProvider);
      await dio.put('/restaurant/categories/${category.id}', data: {
        'name': result.name,
        'description': result.description,
      });
      ref.invalidate(categoriesProvider);
      if (context.mounted) showSuccessSnackBar(context, 'Category updated');
    } catch (error) {
      if (context.mounted) showErrorSnackBar(context, apiErrorMessage(error));
    }
  }

  Future<void> _deleteCategory(BuildContext context, WidgetRef ref, Category category) async {
    final confirmed = await showConfirmDialog(
      context,
      title: 'Delete category?',
      message: category.menuItemCount > 0
          ? '${category.name} has ${category.menuItemCount} menu item(s). '
              'Categories with items attached can\'t be deleted.'
          : 'This will permanently delete "${category.name}".',
      confirmLabel: 'Delete',
    );
    if (!confirmed) return;

    try {
      final dio = ref.read(dioProvider);
      await dio.delete('/restaurant/categories/${category.id}');
      ref.invalidate(categoriesProvider);
      if (context.mounted) showSuccessSnackBar(context, 'Category deleted');
    } catch (error) {
      if (context.mounted) showErrorSnackBar(context, apiErrorMessage(error));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categoriesAsync = ref.watch(categoriesProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _addCategory(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('Add Category'),
      ),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(categoriesProvider),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.all(Responsive.pagePadding(context)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Categories', style: AppTextStyles.displayMedium),
              const SizedBox(height: 24),
              categoriesAsync.when(
                loading: () => const Padding(
                  padding: EdgeInsets.symmetric(vertical: 60),
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (error, _) => Text(
                  apiErrorMessage(error),
                  style: AppTextStyles.body.copyWith(color: AppColors.error),
                ),
                data: (categories) {
                  if (categories.isEmpty) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 40),
                      child: Text(
                        'No categories yet. Add one to start building your menu.',
                        style: AppTextStyles.bodySmall.copyWith(color: AppColors.textMuted),
                      ),
                    );
                  }

                  return Column(
                    children: [
                      for (final category in categories)
                        Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(category.name, style: AppTextStyles.title),
                                    if (category.description.isNotEmpty) ...[
                                      const SizedBox(height: 4),
                                      Text(category.description, style: AppTextStyles.bodySmall),
                                    ],
                                    const SizedBox(height: 4),
                                    Text(
                                      '${category.menuItemCount} item(s)',
                                      style: AppTextStyles.bodySmall.copyWith(color: AppColors.textMuted),
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                onPressed: () => _editCategory(context, ref, category),
                                icon: const Icon(Icons.edit_outlined, size: 20),
                                tooltip: 'Edit',
                              ),
                              IconButton(
                                onPressed: () => _deleteCategory(context, ref, category),
                                icon: const Icon(Icons.delete_outline, size: 20, color: AppColors.error),
                                tooltip: 'Delete',
                              ),
                            ],
                          ),
                        ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 80), // room for the FAB
            ],
          ),
        ),
      ),
    );
  }
}
