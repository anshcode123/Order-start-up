import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:scanserve/core/constants/app_routes.dart';
import 'package:scanserve/core/network/api_exception.dart';
import 'package:scanserve/core/theme/app_colors.dart';
import 'package:scanserve/core/theme/app_text_styles.dart';
import 'package:scanserve/core/utils/responsive.dart';
import 'package:scanserve/features/restaurant_admin/widgets/order_status_chip.dart';
import 'package:scanserve/features/super_admin/providers/restaurant_providers.dart';
import 'package:scanserve/features/super_admin/widgets/stat_card.dart';
import 'package:scanserve/shared/widgets/app_button.dart';

import 'package:scanserve/shared/widgets/status_badge.dart';

class SuperAdminAnalyticsScreen extends ConsumerStatefulWidget {
  const SuperAdminAnalyticsScreen({super.key});

  @override
  ConsumerState<SuperAdminAnalyticsScreen> createState() =>
      _SuperAdminAnalyticsScreenState();
}

class _SuperAdminAnalyticsScreenState
    extends ConsumerState<SuperAdminAnalyticsScreen> {
  String _selectedPeriod = 'all';

  static const _periods = [
    (key: 'all', label: 'All Time'),
    (key: 'today', label: 'Today'),
    (key: 'yesterday', label: 'Yesterday'),
    (key: 'thisweek', label: 'This Week'),
    (key: '7days', label: 'Last 7 Days'),
    (key: '30days', label: 'Last 30 Days'),
    (key: 'thismonth', label: 'This Month'),
  ];

  @override
  Widget build(BuildContext context) {
    final analyticsAsync = ref.watch(orderAnalyticsProvider(_selectedPeriod));
    final isMobile = Responsive.isMobile(context);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: RefreshIndicator(
        onRefresh: () async =>
            ref.invalidate(orderAnalyticsProvider(_selectedPeriod)),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.all(Responsive.pagePadding(context)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header & Period Filter Chips
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Platform Order Analytics',
                          style: AppTextStyles.displayMedium),
                      const SizedBox(height: 4),
                      Text(
                        'Detailed order volume, status breakdown, and per-restaurant performance',
                        style: AppTextStyles.bodySmall
                            .copyWith(color: AppColors.textMuted),
                      ),
                    ],
                  ),
                  IconButton(
                    tooltip: 'Refresh analytics',
                    icon: const Icon(Icons.refresh,
                        color: AppColors.textSecondary),
                    onPressed: () =>
                        ref.invalidate(orderAnalyticsProvider(_selectedPeriod)),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Date Period Selector
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    for (final p in _periods) ...[
                      ChoiceChip(
                        label: Text(p.label),
                        selected: _selectedPeriod == p.key,
                        onSelected: (selected) {
                          if (selected) setState(() => _selectedPeriod = p.key);
                        },
                        selectedColor: AppColors.primary,
                        labelStyle: TextStyle(
                          color: _selectedPeriod == p.key
                              ? Colors.white
                              : AppColors.textPrimary,
                          fontWeight: _selectedPeriod == p.key
                              ? FontWeight.w600
                              : FontWeight.w400,
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 24),

              analyticsAsync.when(
                loading: () => const Padding(
                  padding: EdgeInsets.symmetric(vertical: 80),
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
                        onPressed: () => ref.invalidate(
                            orderAnalyticsProvider(_selectedPeriod)),
                      ),
                    ],
                  ),
                ),
                data: (data) => Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // High-level time window order totals
                    GridView(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: isMobile ? 2 : 4,
                        mainAxisSpacing: 16,
                        crossAxisSpacing: 16,
                        childAspectRatio: isMobile ? 1.5 : 1.7,
                      ),
                      children: [
                        StatCard(
                          label: 'Total Orders',
                          value: data.totalOrders,
                          icon: Icons.receipt_long_outlined,
                          accentColor: AppColors.primaryDark,
                        ),
                        StatCard(
                          label: "Today's Orders",
                          value: data.todayOrders,
                          icon: Icons.today_outlined,
                          accentColor: Colors.blue.shade700,
                        ),
                        StatCard(
                          label: "This Week's Orders",
                          value: data.thisWeekOrders,
                          icon: Icons.date_range_outlined,
                          accentColor: Colors.teal.shade700,
                        ),
                        StatCard(
                          label: "This Month's Orders",
                          value: data.thisMonthOrders,
                          icon: Icons.calendar_month_outlined,
                          accentColor: Colors.indigo.shade700,
                        ),
                      ],
                    ),
                    const SizedBox(height: 32),

                    // Order Status Breakdown for Selected Period
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Order Status Breakdown',
                                      style: AppTextStyles.title),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Period orders: ${data.filteredOrders} · Revenue: ₹${data.filteredRevenue}',
                                    style: AppTextStyles.bodySmall
                                        .copyWith(color: AppColors.textMuted),
                                  ),
                                ],
                              ),
                              Chip(
                                label: Text(
                                  _periods
                                      .firstWhere(
                                          (p) => p.key == _selectedPeriod)
                                      .label,
                                  style: AppTextStyles.bodySmall.copyWith(
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.primaryDark,
                                  ),
                                ),
                                backgroundColor: AppColors.primaryLight,
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),
                          Wrap(
                            spacing: 16,
                            runSpacing: 16,
                            children: [
                              for (final entry in data.statusBreakdown.entries)
                                Container(
                                  width: isMobile ? double.infinity : 190,
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: AppColors.background,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: AppColors.border),
                                  ),
                                  child: Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      OrderStatusChip(status: entry.key),
                                      Text(
                                        '${entry.value}',
                                        style: AppTextStyles.title
                                            .copyWith(fontSize: 18),
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),

                    // Per-Restaurant Order Statistics
                    const Text('Restaurant Order Statistics',
                        style: AppTextStyles.title),
                    const SizedBox(height: 4),
                    Text(
                      'Volume and order statuses across each registered restaurant',
                      style: AppTextStyles.bodySmall
                          .copyWith(color: AppColors.textMuted),
                    ),
                    const SizedBox(height: 16),

                    if (data.restaurants.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(32),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: const Center(
                          child: Text('No restaurant data available.'),
                        ),
                      )
                    else
                      Container(
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: DataTable(
                            headingRowColor:
                                WidgetStateProperty.all(AppColors.background),
                            columns: const [
                              DataColumn(label: Text('Restaurant')),
                              DataColumn(label: Text('Status')),
                              DataColumn(
                                  label: Text('Total Orders'), numeric: true),
                              DataColumn(label: Text("Today's"), numeric: true),
                              DataColumn(label: Text('Pending'), numeric: true),
                              DataColumn(
                                  label: Text('Ready'), numeric: true),
                              DataColumn(label: Text('Actions')),
                            ],
                            rows: [
                              for (final r in data.restaurants)
                                DataRow(
                                  cells: [
                                    DataCell(
                                      Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Text(
                                            r.name,
                                            style: AppTextStyles.bodySmall
                                                .copyWith(
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                          Text(
                                            '/${r.slug}',
                                            style: AppTextStyles.bodySmall
                                                .copyWith(
                                              color: AppColors.textMuted,
                                              fontSize: 11,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    DataCell(StatusBadge(isActive: r.isActive)),
                                    DataCell(Text('${r.totalOrders}')),
                                    DataCell(Text('${r.todayOrders}')),
                                    DataCell(
                                      Text(
                                        '${r.pendingOrders}',
                                        style: TextStyle(
                                          fontWeight: r.pendingOrders > 0
                                              ? FontWeight.bold
                                              : FontWeight.normal,
                                          color: r.pendingOrders > 0
                                              ? Colors.orange.shade800
                                              : null,
                                        ),
                                      ),
                                    ),
                                    DataCell(Text('${r.completedOrders}')),
                                    DataCell(
                                      OutlinedButton(
                                        onPressed: () => context.go(
                                          AppRoutes.superAdminRestaurantDetail(
                                              r.id),
                                        ),
                                        child: const Text('Details'),
                                      ),
                                    ),
                                  ],
                                ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
