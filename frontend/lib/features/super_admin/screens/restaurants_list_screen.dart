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
import 'package:scanserve/shared/widgets/app_dialogs.dart';
import 'package:scanserve/shared/widgets/status_badge.dart';

class RestaurantsListScreen extends ConsumerWidget {
  const RestaurantsListScreen({super.key});

  Future<void> _toggleStatus(BuildContext context, WidgetRef ref, Restaurant restaurant) async {
    final activating = !restaurant.isActive;
    final confirmed = await showConfirmDialog(
      context,
      title: activating ? 'Enable restaurant?' : 'Disable restaurant?',
      message: activating
          ? '${restaurant.name} will become active again and its menu link will work.'
          : '${restaurant.name} will be marked inactive. Its menu link will stop working '
              'until re-enabled. This does not delete any data.',
      confirmLabel: activating ? 'Enable' : 'Disable',
    );
    if (!confirmed) return;

    try {
      final dio = ref.read(dioProvider);
      await dio.patch(
        '/admin/restaurants/${restaurant.id}/status',
        data: {'status': activating ? 'ACTIVE' : 'INACTIVE'},
      );
      ref.invalidate(restaurantsListProvider);
      if (context.mounted) {
        showSuccessSnackBar(
          context,
          activating ? 'Restaurant enabled' : 'Restaurant disabled',
        );
      }
    } catch (error) {
      if (context.mounted) showErrorSnackBar(context, apiErrorMessage(error));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final restaurantsAsync = ref.watch(restaurantsListProvider);
    final isMobile = Responsive.isMobile(context);

    return Scaffold(
      backgroundColor: AppColors.background,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.go(AppRoutes.superAdminRestaurantCreate),
        icon: const Icon(Icons.add),
        label: const Text('Create Restaurant'),
      ),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(restaurantsListProvider),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.all(Responsive.pagePadding(context)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Restaurants', style: AppTextStyles.displayMedium),
              const SizedBox(height: 24),
              restaurantsAsync.when(
                loading: () => const Padding(
                  padding: EdgeInsets.symmetric(vertical: 60),
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (error, _) => Text(
                  apiErrorMessage(error),
                  style: AppTextStyles.body.copyWith(color: AppColors.error),
                ),
                data: (restaurants) {
                  if (restaurants.isEmpty) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 40),
                      child: Text(
                        'No restaurants yet. Create the first one to get started.',
                        style: AppTextStyles.bodySmall.copyWith(color: AppColors.textMuted),
                      ),
                    );
                  }

                  return Column(
                    children: [
                      for (final restaurant in restaurants)
                        _RestaurantCard(
                          restaurant: restaurant,
                          isMobile: isMobile,
                          onToggleStatus: () => _toggleStatus(context, ref, restaurant),
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

class _RestaurantCard extends StatelessWidget {
  const _RestaurantCard({
    required this.restaurant,
    required this.isMobile,
    required this.onToggleStatus,
  });

  final Restaurant restaurant;
  final bool isMobile;
  final VoidCallback onToggleStatus;

  @override
  Widget build(BuildContext context) {
    final actions = Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        OutlinedButton(
          onPressed: () => context.go(AppRoutes.superAdminRestaurantDetail(restaurant.id)),
          child: const Text('View'),
        ),
        OutlinedButton(
          onPressed: () => context.go(AppRoutes.superAdminRestaurantDetail(restaurant.id)),
          child: const Text('Edit'),
        ),
        OutlinedButton(
          onPressed: onToggleStatus,
          child: Text(restaurant.isActive ? 'Disable' : 'Enable'),
        ),
        OutlinedButton(
          onPressed: () => context.go(AppRoutes.superAdminRestaurantQr(restaurant.id)),
          child: const Text('QR'),
        ),
      ],
    );

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(20),
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
                child: Text(restaurant.name, style: AppTextStyles.title),
              ),
              StatusBadge(isActive: restaurant.isActive),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            restaurant.adminEmail ?? 'No admin on record',
            style: AppTextStyles.bodySmall,
          ),
          Text('/${restaurant.slug}', style: AppTextStyles.bodySmall.copyWith(color: AppColors.textMuted)),
          if (restaurant.createdAt != null)
            Text(
              'Created ${restaurant.createdAt!.toLocal().toString().split(' ').first}',
              style: AppTextStyles.bodySmall.copyWith(color: AppColors.textMuted),
            ),
          const SizedBox(height: 16),
          actions,
        ],
      ),
    );
  }
}
