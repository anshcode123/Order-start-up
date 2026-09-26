const prisma = require('../lib/prisma');
const {
  getTodayRange,
  getThisWeekRange,
  getThisMonthRange,
  getDateRangeForPeriod,
} = require('../utils/dateRange');
const { ORDER_STATUSES } = require('../services/orderService');

function buildStatusBreakdown(groupedStatusRows) {
  const breakdown = {};
  for (const status of ORDER_STATUSES) {
    breakdown[status] = 0;
  }
  for (const row of groupedStatusRows) {
    if (breakdown[row.status] !== undefined) {
      breakdown[row.status] = row._count.id;
    }
  }
  return breakdown;
}

// GET /api/super-admin/dashboard/stats
async function getPlatformStats(req, res, next) {
  try {
    const todayRange = getTodayRange();

    const [totalRestaurants, activeRestaurants, totalOrders, todayOrders] = await Promise.all([
      prisma.restaurant.count(),
      prisma.restaurant.count({ where: { isActive: true } }),
      prisma.order.count(),
      prisma.order.count({
        where: { createdAt: { gte: todayRange.start, lte: todayRange.end } },
      }),
    ]);

    const [pendingOrders, readyOrders, recentRestaurants] = await Promise.all([
      prisma.order.count({ where: { status: 'PENDING' } }),
      prisma.order.count({ where: { status: 'READY' } }),
      prisma.restaurant.findMany({
        orderBy: { createdAt: 'desc' },
        take: 5,
        select: {
          id: true,
          name: true,
          slug: true,
          phone: true,
          email: true,
          isActive: true,
          createdAt: true,
        },
      }),
    ]);

    res.status(200).json({
      success: true,
      stats: {
        totalRestaurants,
        activeRestaurants,
        inactiveRestaurants: totalRestaurants - activeRestaurants,
        totalOrders,
        todayOrders,
        pendingOrders,
        readyOrders,
        completedOrders: readyOrders,
      },
      recentRestaurants,
    });
  } catch (err) {
    next(err);
  }
}

// GET /api/super-admin/analytics/orders
async function getOrderAnalytics(req, res, next) {
  try {
    const { period, startDate, endDate } = req.query;
    const todayRange = getTodayRange();
    const thisWeekRange = getThisWeekRange();
    const thisMonthRange = getThisMonthRange();
    const selectedRange = getDateRangeForPeriod(period, startDate, endDate);

    const periodWhere = {};
    if (selectedRange) {
      periodWhere.createdAt = { gte: selectedRange.start, lte: selectedRange.end };
    }

    const [
      totalOrdersAllTime,
      todayOrdersCount,
      thisWeekOrdersCount,
      thisMonthOrdersCount,
      filteredOrdersCount,
    ] = await Promise.all([
      prisma.order.count(),
      prisma.order.count({
        where: { createdAt: { gte: todayRange.start, lte: todayRange.end } },
      }),
      prisma.order.count({
        where: { createdAt: { gte: thisWeekRange.start, lte: thisWeekRange.end } },
      }),
      prisma.order.count({
        where: { createdAt: { gte: thisMonthRange.start, lte: thisMonthRange.end } },
      }),
      prisma.order.count({ where: periodWhere }),
    ]);

    const [
      filteredRevenueAgg,
      groupedStatusRows,
      restaurantsWithOrderCounts,
    ] = await Promise.all([
      prisma.order.aggregate({
        where: periodWhere,
        _sum: { totalAmount: true },
      }),
      prisma.order.groupBy({
        by: ['status'],
        where: periodWhere,
        _count: { id: true },
      }),
      prisma.restaurant.findMany({
        select: {
          id: true,
          name: true,
          slug: true,
          phone: true,
          email: true,
          isActive: true,
          createdAt: true,
          _count: {
            select: { orders: true },
          },
        },
        orderBy: { name: 'asc' },
      }),
    ]);

    const [todayByRest, pendingByRest, readyByRest] = await Promise.all([
      prisma.order.groupBy({
        by: ['restaurantId'],
        where: { createdAt: { gte: todayRange.start, lte: todayRange.end } },
        _count: { id: true },
      }),
      prisma.order.groupBy({
        by: ['restaurantId'],
        where: { status: 'PENDING' },
        _count: { id: true },
      }),
      prisma.order.groupBy({
        by: ['restaurantId'],
        where: { status: 'READY' },
        _count: { id: true },
      }),
    ]);

    const todayMap = new Map(todayByRest.map((r) => [r.restaurantId, r._count.id]));
    const pendingMap = new Map(pendingByRest.map((r) => [r.restaurantId, r._count.id]));
    const readyMap = new Map(readyByRest.map((r) => [r.restaurantId, r._count.id]));

    const restaurantOrderStats = restaurantsWithOrderCounts.map((r) => ({
      id: r.id,
      name: r.name,
      slug: r.slug,
      phone: r.phone,
      email: r.email,
      isActive: r.isActive,
      totalOrders: r._count.orders,
      todayOrders: todayMap.get(r.id) || 0,
      pendingOrders: pendingMap.get(r.id) || 0,
      readyOrders: readyMap.get(r.id) || 0,
      completedOrders: readyMap.get(r.id) || 0,
    }));

    const statusBreakdown = buildStatusBreakdown(groupedStatusRows);
    const summary = {
      totalOrders: totalOrdersAllTime,
      todayOrders: todayOrdersCount,
      thisWeekOrders: thisWeekOrdersCount,
      thisMonthOrders: thisMonthOrdersCount,
      filteredOrders: filteredOrdersCount,
      filteredRevenue: filteredRevenueAgg._sum.totalAmount
        ? filteredRevenueAgg._sum.totalAmount.toString()
        : '0',
    };

    res.status(200).json({
      success: true,
      filter: {
        period: period || 'all',
        startDate: selectedRange ? selectedRange.start : null,
        endDate: selectedRange ? selectedRange.end : null,
      },
      summary,
      statusBreakdown,
      restaurants: restaurantOrderStats,
      data: {
        summary,
        statusBreakdown,
        restaurants: restaurantOrderStats,
      },
    });
  } catch (err) {
    next(err);
  }
}

// GET /api/super-admin/restaurants/:id/stats
async function getRestaurantStats(req, res, next) {
  try {
    const { id } = req.params;
    const restaurant = await prisma.restaurant.findUnique({
      where: { id },
      select: {
        id: true,
        name: true,
        slug: true,
        description: true,
        phone: true,
        email: true,
        address: true,
        whatsappNumber: true,
        isActive: true,
        requireTableNumber: true,
        createdAt: true,
      },
    });

    if (!restaurant) {
      return res.status(404).json({ success: false, message: 'Restaurant not found' });
    }

    const todayRange = getTodayRange();

    const [
      totalCategories,
      totalMenuItems,
      availableMenuItems,
      totalOrders,
      todayOrders,
    ] = await Promise.all([
      prisma.category.count({ where: { restaurantId: id } }),
      prisma.menuItem.count({ where: { restaurantId: id } }),
      prisma.menuItem.count({ where: { restaurantId: id, isAvailable: true } }),
      prisma.order.count({ where: { restaurantId: id } }),
      prisma.order.count({
        where: {
          restaurantId: id,
          createdAt: { gte: todayRange.start, lte: todayRange.end },
        },
      }),
    ]);

    const [
      pendingOrders,
      readyOrders,
      revenueAgg,
      groupedStatusRows,
    ] = await Promise.all([
      prisma.order.count({ where: { restaurantId: id, status: 'PENDING' } }),
      prisma.order.count({ where: { restaurantId: id, status: 'READY' } }),
      prisma.order.aggregate({
        where: { restaurantId: id },
        _sum: { totalAmount: true },
      }),
      prisma.order.groupBy({
        by: ['status'],
        where: { restaurantId: id },
        _count: { id: true },
      }),
    ]);

    res.status(200).json({
      success: true,
      restaurant,
      stats: {
        totalCategories,
        totalMenuItems,
        availableMenuItems,
        unavailableMenuItems: totalMenuItems - availableMenuItems,
        totalOrders,
        todayOrders,
        pendingOrders,
        readyOrders,
        completedOrders: readyOrders,
        totalRevenue: revenueAgg._sum.totalAmount
          ? revenueAgg._sum.totalAmount.toString()
          : '0',
        statusBreakdown: buildStatusBreakdown(groupedStatusRows),
      },
    });
  } catch (err) {
    next(err);
  }
}

module.exports = {
  getPlatformStats,
  getOrderAnalytics,
  getRestaurantStats,
};
