const express = require('express');
const {
  getMenuItems,
  getMenuItemById,
  createMenuItem,
  updateMenuItem,
  updateAvailability,
  deleteMenuItem,
  uploadImage,
} = require('../controllers/menuItemController');
const { protect, authorize } = require('../middleware/auth');
const { uploadMenuItemImage } = require('../middleware/upload');

const router = express.Router();

router.use(protect, authorize('RESTAURANT_ADMIN'));

router.get('/', getMenuItems);
router.get('/:id', getMenuItemById);
router.post('/', createMenuItem);
router.put('/:id', updateMenuItem);
router.patch('/:id/availability', updateAvailability);
router.delete('/:id', deleteMenuItem);

// multipart/form-data, field name "image". Invoked as a callback (not
// plain middleware) so a bad file type/size turns into a clean 400 JSON
// response right here, instead of an uncaught multer error reaching the
// generic error handler as a 500.
router.post('/upload-image', (req, res, next) => {
  uploadMenuItemImage(req, res, (err) => {
    if (err) {
      const statusCode = err.code === 'LIMIT_FILE_SIZE' ? 400 : err.statusCode || 400;
      return res.status(statusCode).json({
        success: false,
        message: err.code === 'LIMIT_FILE_SIZE' ? 'Image must be 5MB or smaller' : err.message,
      });
    }
    next();
  });
}, uploadImage);

module.exports = router;
