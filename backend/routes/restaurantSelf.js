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

router.post(
  '/settings/logo',
  (req, res, next) => {
    uploadLogoImage(req, res, (err) => {
      if (err) {
        const statusCode = err.code === 'LIMIT_FILE_SIZE' ? 400 : err.statusCode || 400;
        return res.status(statusCode).json({
          success: false,
          message: err.code === 'LIMIT_FILE_SIZE' ? 'Image must be 5MB or smaller' : err.message,
        });
      }
      next();
    });
  },
  uploadLogo
);

router.get('/subscription', getOwnSubscription);

module.exports = router;
