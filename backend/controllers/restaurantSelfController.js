const prisma = require('../lib/prisma');
const { generateMenuQrDataUrl } = require('../services/qrService');

// GET /api/restaurant/dashboard
// Real counts for the authenticated Restaurant Admin's own restaurant
// only - Phase 4 spec #19 ("Do not show fake statistics").
async function getRestaurantAdminDashboard(req, res, next) {
  try {
    const restaurantId = req.user.restaurantId;

    const [totalCategories, totalMenuItems, availableItems] = await Promise.all([
      prisma.category.count({ where: { restaurantId } }),
      prisma.menuItem.count({ where: { restaurantId } }),
      prisma.menuItem.count({ where: { restaurantId, isAvailable: true } }),
    ]);

    res.status(200).json({
      success: true,
      message: 'Dashboard stats fetched successfully',
      data: {
        totalCategories,
        totalMenuItems,
        availableItems,
        unavailableItems: totalMenuItems - availableItems,
      },
    });
  } catch (err) {
    next(err);
  }
}

// GET /api/restaurant/qr
// Same QR image the Super Admin sees at
// GET /api/admin/restaurants/:id/qr, but self-service: the restaurant
// is always the caller's own (req.user.restaurantId), never a param.
async function getOwnRestaurantQr(req, res, next) {
  try {
    const restaurant = await prisma.restaurant.findUnique({
      where: { id: req.user.restaurantId },
    });
    if (!restaurant) {
      return res.status(404).json({ success: false, message: 'Restaurant not found' });
    }

    const { menuUrl, dataUrl } = await generateMenuQrDataUrl(restaurant.slug);

    res.status(200).json({
      success: true,
      message: 'QR code generated successfully',
      data: { restaurantName: restaurant.name, menuUrl, qrDataUrl: dataUrl },
    });
  } catch (err) {
    next(err);
  }
}

module.exports = { getRestaurantAdminDashboard, getOwnRestaurantQr };
