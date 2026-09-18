const express = require('express');
const {
  getRestaurantAdminDashboard,
  getOwnRestaurantQr,
} = require('../controllers/restaurantSelfController');
const { protect, authorize } = require('../middleware/auth');

const router = express.Router();

router.use(protect, authorize('RESTAURANT_ADMIN'));

router.get('/dashboard', getRestaurantAdminDashboard);
router.get('/qr', getOwnRestaurantQr);

module.exports = router;
