import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:scanserve/core/constants/app_routes.dart';
import 'package:scanserve/core/network/api_exception.dart';
import 'package:scanserve/core/network/dio_client.dart';
import 'package:scanserve/core/theme/app_colors.dart';
import 'package:scanserve/core/theme/app_text_styles.dart';
import 'package:scanserve/core/utils/responsive.dart';
import 'package:scanserve/features/restaurant_admin/providers/menu_providers.dart';
import 'package:scanserve/features/restaurant_admin/widgets/menu_item_card.dart';
import 'package:scanserve/shared/models/category.dart';
import 'package:scanserve/shared/models/menu_item.dart';
import 'package:scanserve/shared/widgets/app_dialogs.dart';

enum _AvailabilityFilter { all, available, unavailable }

/// The restaurant's menu, organized by category, with category /
/// availability / search filters applied client-side (Phase 4 spec #16,
/// #17 - "keep the UI simple").
class MenuScreen extends ConsumerStatefulWidget {
  const MenuScreen({super.key});

  @override
  ConsumerState<MenuScreen> createState() => _MenuScreenState();
}

class _MenuScreenState extends ConsumerState<MenuScreen> {
  String? _categoryFilter; // categoryId, or null for "All categories"
  _AvailabilityFilter _availabilityFilter = _AvailabilityFilter.all;
  final _searchController = TextEditingController();
  String _search = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _toggleAvailability(MenuItem item) async {
    try {
      final dio = ref.read(dioProvider);
      await dio.patch('/restaurant/menu-items/${item.id}/availability', data: {
        'isAvailable': !item.isAvailable,
      });
      ref.invalidate(menuItemsProvider);
      ref.invalidate(restaurantAdminStatsProvider);
      if (mounted) {
        showSuccessSnackBar(context, item.isAvailable ? 'Item disabled' : 'Item enabled');
      }
    } catch (error) {
      if (mounted) showErrorSnackBar(context, apiErrorMessage(error));
    }
  }

  Future<void> _deleteItem(MenuItem item) async {
    final confirmed = await showConfirmDialog(
      context,
      title: 'Delete menu item?',
      message: 'This will permanently delete "${item.name}".',
      confirmLabel: 'Delete',
    );
    if (!confirmed) return;

    try {
      final dio = ref.read(dioProvider);
      await dio.delete('/restaurant/menu-items/${item.id}');
      ref.invalidate(menuItemsProvider);
      ref.invalidate(restaurantAdminStatsProvider);
      if (mounted) showSuccessSnackBar(context, 'Menu item deleted');
    } catch (error) {
      if (mounted) showErrorSnackBar(context, apiErrorMessage(error));
    }
  }

  List<MenuItem> _applyFilters(List<MenuItem> items) {
    return items.where((item) {
      if (_categoryFilter != null && item.categoryId != _categoryFilter) return false;
      if (_availabilityFilter == _AvailabilityFilter.available && !item.isAvailable) return false;
      if (_availabilityFilter == _AvailabilityFilter.unavailable && item.isAvailable) return false;
      if (_search.isNotEmpty && !item.name.toLowerCase().contains(_search.toLowerCase())) {
        return false;
      }
      return true;
    }).toList();
  }

  Map<String, List<MenuItem>> _groupByCategory(List<MenuItem> items) {
    final grouped = <String, List<MenuItem>>{};
    for (final item in items) {
      final key = item.categoryName ?? 'Uncategorized';
      grouped.putIfAbsent(key, () => []).add(item);
    }
    return grouped;
  }

  @override
  Widget build(BuildContext context) {
    final itemsAsync = ref.watch(menuItemsProvider);
    final categoriesAsync = ref.watch(categoriesProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.go(AppRoutes.dashboardMenuItemCreate),
        icon: const Icon(Icons.add),
        label: const Text('Add Menu Item'),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(menuItemsProvider);
          ref.invalidate(categoriesProvider);
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.all(Responsive.pagePadding(context)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Menu', style: AppTextStyles.displayMedium),
              const SizedBox(height: 20),
              _buildFilters(categoriesAsync.valueOrNull ?? const []),
              const SizedBox(height: 20),
              itemsAsync.when(
                loading: () => const Padding(
                  padding: EdgeInsets.symmetric(vertical: 60),
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (error, _) => Text(
                  apiErrorMessage(error),
                  style: AppTextStyles.body.copyWith(color: AppColors.error),
                ),
                data: (allItems) {
                  if (allItems.isEmpty) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 40),
                      child: Text(
                        'No menu items yet.',
                        style: AppTextStyles.bodySmall.copyWith(color: AppColors.textMuted),
                      ),
                    );
                  }

                  final filtered = _applyFilters(allItems);
                  if (filtered.isEmpty) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 40),
                      child: Text(
                        'No menu items match these filters.',
                        style: AppTextStyles.bodySmall.copyWith(color: AppColors.textMuted),
                      ),
                    );
                  }

                  final grouped = _groupByCategory(filtered);
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (final entry in grouped.entries) ...[
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12, top: 4),
                          child: Text(entry.key, style: AppTextStyles.title),
                        ),
                        for (final item in entry.value)
                          MenuItemCard(
                            item: item,
                            onEdit: () => context.go(AppRoutes.dashboardMenuItemEdit(item.id)),
                            onToggleAvailability: () => _toggleAvailability(item),
                            onDelete: () => _deleteItem(item),
                          ),
                        const SizedBox(height: 12),
                      ],
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

  Widget _buildFilters(List<Category> categories) {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        SizedBox(
          width: 220,
          child: TextField(
            controller: _searchController,
            decoration: const InputDecoration(
              hintText: 'Search menu items',
              prefixIcon: Icon(Icons.search, size: 20),
              isDense: true,
            ),
            onChanged: (value) => setState(() => _search = value),
          ),
        ),
        DropdownButton<String?>(
          value: _categoryFilter,
          hint: const Text('All categories'),
          underline: const SizedBox.shrink(),
          items: [
            const DropdownMenuItem<String?>(value: null, child: Text('All categories')),
            for (final category in categories)
              DropdownMenuItem<String?>(value: category.id, child: Text(category.name)),
          ],
          onChanged: (value) => setState(() => _categoryFilter = value),
        ),
        DropdownButton<_AvailabilityFilter>(
          value: _availabilityFilter,
          underline: const SizedBox.shrink(),
          items: const [
            DropdownMenuItem(value: _AvailabilityFilter.all, child: Text('All items')),
            DropdownMenuItem(value: _AvailabilityFilter.available, child: Text('Available')),
            DropdownMenuItem(value: _AvailabilityFilter.unavailable, child: Text('Unavailable')),
          ],
          onChanged: (value) => setState(() => _availabilityFilter = value ?? _AvailabilityFilter.all),
        ),
      ],
    );
  }
}
