import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:scanserve/core/network/api_exception.dart';
import 'package:scanserve/core/theme/app_colors.dart';
import 'package:scanserve/core/theme/app_text_styles.dart';
import 'package:scanserve/core/utils/responsive.dart';
import 'package:scanserve/features/customer_menu/providers/public_menu_provider.dart';
import 'package:scanserve/features/customer_menu/widgets/cart_button.dart';
import 'package:scanserve/features/customer_menu/widgets/cart_conflict_dialog.dart';
import 'package:scanserve/features/customer_menu/widgets/category_nav_bar.dart';
import 'package:scanserve/features/customer_menu/widgets/public_menu_item_card.dart';
import 'package:scanserve/shared/models/public_menu.dart';

/// The customer-facing public menu at /menu/:restaurantSlug - what a QR
/// scan lands on. No auth, no admin chrome: just the restaurant header,
/// category filter, and available items.
class PublicMenuScreen extends ConsumerStatefulWidget {
  const PublicMenuScreen({super.key, required this.restaurantSlug});

  final String restaurantSlug;

  @override
  ConsumerState<PublicMenuScreen> createState() => _PublicMenuScreenState();
}

class _PublicMenuScreenState extends ConsumerState<PublicMenuScreen> {
  String? _selectedCategoryId;
  bool _checkedCartConflict = false;

  @override
  Widget build(BuildContext context) {
    final menuAsync = ref.watch(publicMenuProvider(widget.restaurantSlug));

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        title: menuAsync.valueOrNull != null ? Text(menuAsync.value!.restaurant.name) : const Text('Menu'),
        actions: const [CartButton(), SizedBox(width: 8)],
      ),
      body: menuAsync.when(
        loading: () => const _MenuLoadingSkeleton(),
        error: (error, _) => _MenuErrorState(message: apiErrorMessage(error)),
        data: (menu) {
          // Proactively warn about a cross-restaurant cart as soon as the
          // menu loads, rather than waiting for the first Add tap (Phase
          // 5 spec: cart restaurant isolation).
          if (!_checkedCartConflict) {
            _checkedCartConflict = true;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                ensureCartMatchesRestaurant(context, ref, restaurantSlug: menu.restaurant.slug);
              }
            });
          }

          if (menu.categories.isEmpty) {
            return _MenuEmptyState(restaurant: menu.restaurant);
          }

          final visibleCategories = _selectedCategoryId == null
              ? menu.categories
              : menu.categories.where((c) => c.id == _selectedCategoryId).toList();

          final columns = Responsive.isDesktop(context)
              ? 4
              : Responsive.isTablet(context)
                  ? 3
                  : 2;

          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(publicMenuProvider(widget.restaurantSlug)),
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.symmetric(
                horizontal: Responsive.pagePadding(context),
                vertical: 20,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _RestaurantHeader(restaurant: menu.restaurant),
                  const SizedBox(height: 20),
                  CategoryNavBar(
                    categories: menu.categories,
                    selectedCategoryId: _selectedCategoryId,
                    onSelect: (id) => setState(() => _selectedCategoryId = id),
                  ),
                  const SizedBox(height: 20),
                  for (final category in visibleCategories) ...[
                    Text(category.name, style: AppTextStyles.title),
                    if (category.description.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(category.description, style: AppTextStyles.bodySmall),
                    ],
                    const SizedBox(height: 12),
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: category.items.length,
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: columns,
                        mainAxisSpacing: 16,
                        crossAxisSpacing: 16,
                        childAspectRatio: 0.72,
                      ),
                      itemBuilder: (context, index) => PublicMenuItemCard(
                        item: category.items[index],
                        restaurantSlug: menu.restaurant.slug,
                        restaurantName: menu.restaurant.name,
                      ),
                    ),
                    const SizedBox(height: 28),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _RestaurantHeader extends StatelessWidget {
  const _RestaurantHeader({required this.restaurant});

  final PublicRestaurant restaurant;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(restaurant.name, style: AppTextStyles.displayMedium),
        if (restaurant.description.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(restaurant.description, style: AppTextStyles.body),
        ],
        if (restaurant.phone.isNotEmpty || restaurant.address.isNotEmpty) ...[
          const SizedBox(height: 8),
          Wrap(
            spacing: 16,
            runSpacing: 4,
            children: [
              if (restaurant.phone.isNotEmpty)
                _MetaRow(icon: Icons.call_outlined, text: restaurant.phone),
              if (restaurant.address.isNotEmpty)
                _MetaRow(icon: Icons.location_on_outlined, text: restaurant.address),
            ],
          ),
        ],
      ],
    );
  }
}

class _MetaRow extends StatelessWidget {
  const _MetaRow({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: AppColors.textMuted),
        const SizedBox(width: 4),
        Text(text, style: AppTextStyles.bodySmall.copyWith(color: AppColors.textMuted)),
      ],
    );
  }
}

class _MenuLoadingSkeleton extends StatelessWidget {
  const _MenuLoadingSkeleton();

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(Responsive.pagePadding(context)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _skeletonBox(width: 220, height: 28),
          const SizedBox(height: 12),
          _skeletonBox(width: 320, height: 16),
          const SizedBox(height: 24),
          Row(children: [for (int i = 0; i < 4; i++) Padding(
            padding: const EdgeInsets.only(right: 10),
            child: _skeletonBox(width: 80, height: 36, radius: 20),
          )]),
          const SizedBox(height: 24),
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            mainAxisSpacing: 16,
            crossAxisSpacing: 16,
            childAspectRatio: 0.72,
            children: [for (int i = 0; i < 4; i++) _skeletonBox(height: double.infinity)],
          ),
        ],
      ),
    );
  }

  Widget _skeletonBox({double? width, required double height, double radius = 12}) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: AppColors.border,
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}

class _MenuErrorState extends StatelessWidget {
  const _MenuErrorState({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.storefront_outlined, size: 48, color: AppColors.textMuted),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: AppTextStyles.body.copyWith(color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}

class _MenuEmptyState extends StatelessWidget {
  const _MenuEmptyState({required this.restaurant});
  final PublicRestaurant restaurant;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(restaurant.name, style: AppTextStyles.title),
            const SizedBox(height: 12),
            const Icon(Icons.restaurant_menu_outlined, size: 48, color: AppColors.textMuted),
            const SizedBox(height: 16),
            Text(
              'No items are available right now. Please check back soon.',
              textAlign: TextAlign.center,
              style: AppTextStyles.body.copyWith(color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}
