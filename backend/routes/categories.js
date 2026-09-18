const express = require('express');
const {
  getCategories,
  createCategory,
  updateCategory,
  deleteCategory,
} = require('../controllers/categoryController');
const { protect, authorize } = require('../middleware/auth');

const router = express.Router();

// Every route here operates on the caller's own restaurant only -
// restaurantId always comes from req.user.restaurantId inside the
// controller, never from the request. RESTAURANT_ADMIN only: Super
// Admin has no restaurantId of its own, so these routes don't apply to
// it (see routes/admin.js for Super Admin's cross-restaurant views).
router.use(protect, authorize('RESTAURANT_ADMIN'));

router.get('/', getCategories);
router.post('/', createCategory);
router.put('/:id', updateCategory);
router.delete('/:id', deleteCategory);

module.exports = router;
