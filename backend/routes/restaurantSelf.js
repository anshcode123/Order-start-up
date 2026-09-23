const express = require('express');
const {
  getRestaurantAdminDashboard,
  getOwnRestaurantQr,
  getRestaurantSettings,
  updateRestaurantSettings,
  uploadLogo,
} = require('../controllers/restaurantSelfController');
const { protect, authorize } = require('../middleware/auth');
const { uploadLogoImage } = require('../middleware/upload');

const router = express.Router();

router.use(protect, authorize('RESTAURANT_ADMIN'));

router.get('/dashboard', getRestaurantAdminDashboard);
router.get('/qr', getOwnRestaurantQr);
router.get('/settings', getRestaurantSettings);
router.put('/settings', updateRestaurantSettings);
router.post('/settings/logo', uploadLogoImage, uploadLogo);

module.exports = router;

