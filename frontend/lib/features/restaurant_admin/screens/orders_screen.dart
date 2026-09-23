import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:scanserve/core/constants/app_routes.dart';
import 'package:scanserve/core/network/api_exception.dart';
import 'package:scanserve/core/theme/app_colors.dart';
import 'package:scanserve/core/theme/app_text_styles.dart';
import 'package:scanserve/core/utils/responsive.dart';
import 'package:scanserve/features/restaurant_admin/providers/order_providers.dart';
import 'package:scanserve/features/restaurant_admin/widgets/order_status_chip.dart';
import 'package:scanserve/shared/models/restaurant_order.dart';

/// /dashboard/orders - incoming orders for the logged-in Restaurant
/// Admin's own restaurant, split into tabs. Live via restaurantOrdersProvider,
/// which is patched in real-time by socket events.
class OrdersScreen extends ConsumerStatefulWidget {
  const OrdersScreen({super.key});

  @override
  ConsumerState<OrdersScreen> createState() => _OrdersScreenState();
}

const _tabs = [
  (label: 'All', statuses: <String>[]),
  (label: 'New', statuses: ['PENDING']),
  (label: 'Accepted', statuses: ['ACCEPTED']),
  (label: 'Preparing', statuses: ['PREPARING']),
  (label: 'Ready', statuses: ['READY']),
  (label: 'Completed', statuses: ['COMPLETED']),
  (label: 'Cancelled', statuses: ['CANCELLED', 'REJECTED']),
];

class _OrdersScreenState extends ConsumerState<OrdersScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  bool _matchesSearch(RestaurantOrder order) {
    if (_searchQuery.isEmpty) return true;
    final q = _searchQuery.toLowerCase();
    if (order.tableNumber.toLowerCase().contains(q)) return true;
    if (order.id.toLowerCase().contains(q)) return true;
    for (final item in order.items) {
      if (item.itemName.toLowerCase().contains(q)) return true;
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final ordersAsync = ref.watch(restaurantOrdersProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(
              Responsive.pagePadding(context),
              Responsive.pagePadding(context),
              Responsive.pagePadding(context),
              12,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Orders', style: AppTextStyles.displayMedium),
                    const SizedBox(height: 4),
                    Text(
                      'Live order queue updated in real-time',
                      style: AppTextStyles.bodySmall
                          .copyWith(color: AppColors.textMuted),
                    ),
                  ],
                ),
                IconButton(
                  tooltip: 'Refresh orders',
                  icon:
                      const Icon(Icons.refresh, color: AppColors.textSecondary),
                  onPressed: () =>
                      ref.read(restaurantOrdersProvider.notifier).refresh(),
                ),
              ],
            ),
          ),
          Padding(
            padding: EdgeInsets.symmetric(
              horizontal: Responsive.pagePadding(context),
            ),
            child: TextField(
              controller: _searchController,
              onChanged: (val) => setState(() => _searchQuery = val.trim()),
              decoration: InputDecoration(
                hintText: 'Search by table number, order #, or item...',
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
          ),
          const SizedBox(height: 12),
          ordersAsync.when(
            loading: () => const Expanded(
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (error, _) => Expanded(
              child: Center(
                child: Text(
                  apiErrorMessage(error),
                  style: AppTextStyles.body.copyWith(color: AppColors.error),
                ),
              ),
            ),
            data: (allOrders) {
              final filteredOrders = allOrders.where(_matchesSearch).toList();
              return Expanded(
                child: Column(
                  children: [
                    TabBar(
                      controller: _tabController,
                      isScrollable: true,
                      labelColor: AppColors.primaryDark,
                      unselectedLabelColor: AppColors.textSecondary,
                      indicatorColor: AppColors.primary,
                      tabs: [
                        for (final tab in _tabs)
                          Tab(
                            text: tab.statuses.isEmpty
                                ? '${tab.label} (${filteredOrders.length})'
                                : '${tab.label} (${filteredOrders.where((o) => tab.statuses.contains(o.status)).length})',
                          ),
                      ],
                    ),
                    Expanded(
                      child: TabBarView(
                        controller: _tabController,
                        children: [
                          for (final tab in _tabs)
                            _OrderList(
                              orders: tab.statuses.isEmpty
                                  ? filteredOrders
                                  : filteredOrders
                                      .where((o) =>
                                          tab.statuses.contains(o.status))
                                      .toList(),
                              emptyLabel: _searchQuery.isNotEmpty
                                  ? 'No orders found matching "$_searchQuery"'
                                  : 'No ${tab.label.toLowerCase()} orders right now.',
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _OrderList extends ConsumerWidget {
  const _OrderList({required this.orders, required this.emptyLabel});

  final List<RestaurantOrder> orders;
  final String emptyLabel;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (orders.isEmpty) {
      return RefreshIndicator(
        onRefresh: () => ref.read(restaurantOrdersProvider.notifier).refresh(),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 80),
              child: Center(
                child: Text(
                  emptyLabel,
                  style: AppTextStyles.bodySmall
                      .copyWith(color: AppColors.textMuted),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => ref.read(restaurantOrdersProvider.notifier).refresh(),
      child: ListView.builder(
        padding: EdgeInsets.all(Responsive.pagePadding(context)),
        itemCount: orders.length,
        itemBuilder: (context, index) => _OrderCard(order: orders[index]),
      ),
    );
  }
}

class _OrderCard extends ConsumerWidget {
  const _OrderCard({required this.order});
  final RestaurantOrder order;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isNew = order.status == 'PENDING';

    return InkWell(
      onTap: () => context.push(AppRoutes.dashboardOrderDetail(order.id)),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isNew
              ? AppColors.primaryLight.withValues(alpha: 0.4)
              : AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isNew ? AppColors.primary : AppColors.border,
            width: isNew ? 1.5 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'Order #${order.id.substring(0, 8).toUpperCase()}',
                  style: AppTextStyles.title.copyWith(fontSize: 15),
                ),
                const Spacer(),
                OrderStatusChip(status: order.status),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Table ${order.tableNumber} · ${order.totalQuantity} item(s)',
              style:
                  AppTextStyles.bodySmall.copyWith(color: AppColors.textMuted),
            ),
            const SizedBox(height: 10),
            for (final item in order.items)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${item.quantity} × ${item.itemName}',
                        style: AppTextStyles.bodySmall
                            .copyWith(color: AppColors.textPrimary),
                      ),
                    ),
                    Text(
                      item.subtotal,
                      style: AppTextStyles.bodySmall
                          .copyWith(color: AppColors.textPrimary),
                    ),
                  ],
                ),
              ),
            const Divider(height: 20, color: AppColors.border),
            Row(
              children: [
                Text('Total',
                    style: AppTextStyles.title.copyWith(fontSize: 14)),
                const Spacer(),
                Text(
                  order.total,
                  style: AppTextStyles.title.copyWith(
                    color: AppColors.primaryDark,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
