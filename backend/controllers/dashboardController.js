const prisma = require('../lib/prisma');

// GET /api/admin/dashboard
async function getSuperAdminDashboard(req, res, next) {
  try {
    const [total, active, recent] = await Promise.all([
      prisma.restaurant.count(),
      prisma.restaurant.count({ where: { isActive: true } }),
      prisma.restaurant.findMany({ orderBy: { createdAt: 'desc' }, take: 5 }),
    ]);

    res.status(200).json({
      success: true,
      stats: {
        totalRestaurants: total,
        activeRestaurants: active,
        inactiveRestaurants: total - active,
      },
      recentRestaurants: recent.map((r) => ({
        id: r.id,
        name: r.name,
        slug: r.slug,
        isActive: r.isActive,
        createdAt: r.createdAt,
      })),
    });
  } catch (err) {
    next(err);
  }
}

module.exports = { getSuperAdminDashboard };
