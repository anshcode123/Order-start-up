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

class RestaurantsListScreen extends ConsumerStatefulWidget {
  const RestaurantsListScreen({super.key});

  @override
  ConsumerState<RestaurantsListScreen> createState() =>
      _RestaurantsListScreenState();
}

class _RestaurantsListScreenState extends ConsumerState<RestaurantsListScreen> {
  final _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _toggleStatus(
      BuildContext context, WidgetRef ref, Restaurant restaurant) async {
    final activating = !restaurant.isActive;
    final confirmed = await showConfirmDialog(
      context,
      title: activating ? 'Activate restaurant?' : 'Deactivate restaurant?',
      message: activating
          ? '${restaurant.name} will become active again and its public menu and order capabilities will be re-enabled.'
          : '${restaurant.name} will be marked inactive. Its public menu will display as temporarily unavailable. No data is lost.',
      confirmLabel: activating ? 'Activate' : 'Deactivate',
    );
    if (!confirmed) return;

    try {
      final dio = ref.read(dioProvider);
      await dio.patch(
        '/admin/restaurants/${restaurant.id}/status',
        data: {'status': activating ? 'ACTIVE' : 'INACTIVE'},
      );
      ref.invalidate(restaurantsListProvider(_searchQuery));
      ref.invalidate(superAdminDashboardProvider);
      if (context.mounted) {
        showSuccessSnackBar(
          context,
          activating ? 'Restaurant activated' : 'Restaurant deactivated',
        );
      }
    } catch (error) {
      if (context.mounted) showErrorSnackBar(context, apiErrorMessage(error));
    }
  }

  @override
  Widget build(BuildContext context) {
    final restaurantsAsync = ref.watch(restaurantsListProvider(_searchQuery));
    final isMobile = Responsive.isMobile(context);

    return Scaffold(
      backgroundColor: AppColors.background,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.go(AppRoutes.superAdminRestaurantCreate),
        icon: const Icon(Icons.add),
        label: const Text('Create Restaurant'),
      ),
      body: RefreshIndicator(
        onRefresh: () async =>
            ref.invalidate(restaurantsListProvider(_searchQuery)),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.all(Responsive.pagePadding(context)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Restaurants',
                          style: AppTextStyles.displayMedium),
                      const SizedBox(height: 4),
                      Text(
                        'Manage, search, and monitor all platform restaurants',
                        style: AppTextStyles.bodySmall
                            .copyWith(color: AppColors.textMuted),
                      ),
                    ],
                  ),
                  if (!isMobile)
                    AppPrimaryButton(
                      label: 'Create Restaurant',
                      onPressed: () =>
                          context.go(AppRoutes.superAdminRestaurantCreate),
                    ),
                ],
              ),
              const SizedBox(height: 20),

              // Search Bar
              TextField(
                controller: _searchController,
                onChanged: (val) => setState(() => _searchQuery = val.trim()),
                decoration: InputDecoration(
                  hintText:
                      'Search restaurants by name, slug, email, or phone...',
                  prefixIcon: const Icon(Icons.search, size: 20),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 18),
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _searchQuery = '');
                          },
                        )
                      : null,
                  filled: true,
                  fillColor: AppColors.surface,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: AppColors.border),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              restaurantsAsync.when(
                loading: () => const Padding(
                  padding: EdgeInsets.symmetric(vertical: 60),
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (error, _) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 40),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        apiErrorMessage(error),
                        style:
                            AppTextStyles.body.copyWith(color: AppColors.error),
                      ),
                      const SizedBox(height: 12),
                      AppPrimaryButton(
                        label: 'Retry',
                        onPressed: () => ref
                            .invalidate(restaurantsListProvider(_searchQuery)),
                      ),
                    ],
                  ),
                ),
                data: (restaurants) {
                  if (restaurants.isEmpty) {
                    return Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(40),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Center(
                        child: Text(
                          _searchQuery.isNotEmpty
                              ? 'No restaurants match "$_searchQuery".'
                              : 'No restaurants yet. Create the first one to get started.',
                          style: AppTextStyles.bodySmall
                              .copyWith(color: AppColors.textMuted),
                        ),
                      ),
                    );
                  }

                  return Column(
                    children: [
                      for (final restaurant in restaurants)
                        _RestaurantCard(
                          restaurant: restaurant,
                          isMobile: isMobile,
                          onToggleStatus: () =>
                              _toggleStatus(context, ref, restaurant),
                        ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 80),
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
        OutlinedButton.icon(
          icon: const Icon(Icons.visibility_outlined, size: 16),
          label: const Text('Details'),
          onPressed: () =>
              context.go(AppRoutes.superAdminRestaurantDetail(restaurant.id)),
        ),
        OutlinedButton.icon(
          icon: Icon(
            restaurant.isActive
                ? Icons.block_outlined
                : Icons.check_circle_outline,
            size: 16,
          ),
          label: Text(restaurant.isActive ? 'Deactivate' : 'Activate'),
          style: OutlinedButton.styleFrom(
            foregroundColor:
                restaurant.isActive ? AppColors.error : AppColors.success,
          ),
          onPressed: onToggleStatus,
        ),
        OutlinedButton.icon(
          icon: const Icon(Icons.qr_code_2, size: 16),
          label: const Text('QR Code'),
          onPressed: () =>
              context.go(AppRoutes.superAdminRestaurantQr(restaurant.id)),
        ),
      ],
    );

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(restaurant.name,
                        style: AppTextStyles.title.copyWith(fontSize: 17)),
                    const SizedBox(height: 2),
                    Text(
                      '/${restaurant.slug}',
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.primaryDark,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              StatusBadge(isActive: restaurant.isActive),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1, color: AppColors.border),
          const SizedBox(height: 12),

          // Required details: Phone, Email, Created date
          Wrap(
            spacing: 24,
            runSpacing: 8,
            children: [
              _infoRow(
                Icons.phone_outlined,
                restaurant.phone != null && restaurant.phone!.isNotEmpty
                    ? restaurant.phone!
                    : 'No phone',
              ),
              _infoRow(
                Icons.email_outlined,
                restaurant.email != null && restaurant.email!.isNotEmpty
                    ? restaurant.email!
                    : (restaurant.adminEmail ?? 'No email'),
              ),
              if (restaurant.createdAt != null)
                _infoRow(
                  Icons.calendar_today_outlined,
                  'Created ${restaurant.createdAt!.toLocal().toString().split(' ').first}',
                ),
            ],
          ),
          const SizedBox(height: 16),
          actions,
        ],
      ),
    );
  }

  Widget _infoRow(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: AppColors.textMuted),
        const SizedBox(width: 6),
        Text(text,
            style: AppTextStyles.bodySmall
                .copyWith(color: AppColors.textSecondary)),
      ],
    );
  }
}
