const express = require('express');
const {
  createRestaurant,
  getRestaurants,
  getRestaurantById,
  updateRestaurant,
  updateRestaurantStatus,
  getRestaurantQr,
} = require('../controllers/restaurantController');
const { getSuperAdminDashboard } = require('../controllers/dashboardController');
const { protect, authorize } = require('../middleware/auth');

const router = express.Router();

// Every route here is SUPER_ADMIN only.
router.use(protect, authorize('SUPER_ADMIN'));

router.get('/dashboard', getSuperAdminDashboard);

router.post('/restaurants', createRestaurant);
router.get('/restaurants', getRestaurants);
router.get('/restaurants/:id', getRestaurantById);
router.put('/restaurants/:id', updateRestaurant);
router.patch('/restaurants/:id/status', updateRestaurantStatus);
router.get('/restaurants/:id/qr', getRestaurantQr);

module.exports = router;
