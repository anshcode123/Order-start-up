const express = require('express');
const {
  getPlatformStats,
  getOrderAnalytics,
  getRestaurantStats,
} = require('../controllers/superAdminAnalyticsController');
const { protect, authorize } = require('../middleware/auth');

const router = express.Router();

// Enforce strict SUPER_ADMIN role authorization
router.use(protect, authorize('SUPER_ADMIN'));

router.get('/dashboard/stats', getPlatformStats);
router.get('/analytics/orders', getOrderAnalytics);
router.get('/restaurants/:id/stats', getRestaurantStats);

module.exports = router;

