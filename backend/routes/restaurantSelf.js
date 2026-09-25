const express = require('express');
const {
  getRestaurantAdminDashboard,
  getOwnRestaurantQr,
  getRestaurantSettings,
  updateRestaurantSettings,
  uploadLogo,
} = require('../controllers/restaurantSelfController');
const { getOwnSubscription } = require('../controllers/restaurantSubscriptionController');
const { protect, authorize } = require('../middleware/auth');
const { uploadLogoImage } = require('../middleware/upload');

const router = express.Router();

router.use(protect, authorize('RESTAURANT_ADMIN'));

router.get('/dashboard', getRestaurantAdminDashboard);
router.get('/qr', getOwnRestaurantQr);
router.get('/settings', getRestaurantSettings);
router.put('/settings', updateRestaurantSettings);
router.get('/profile', getRestaurantSettings);
router.put('/profile', updateRestaurantSettings);
router.post('/settings/logo', uploadLogoImage, uploadLogo);
router.get('/subscription', getOwnSubscription);

module.exports = router;
