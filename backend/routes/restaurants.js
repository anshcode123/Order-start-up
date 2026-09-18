const express = require('express');
const { getRestaurantById } = require('../controllers/restaurantController');
const { protect } = require('../middleware/auth');
const { restrictToOwnRestaurant } = require('../middleware/restaurantAccess');

const router = express.Router();

// GET /api/restaurants/:id
// Reachable by SUPER_ADMIN (any restaurant) and RESTAURANT_ADMIN (their
// own restaurant only - restrictToOwnRestaurant checks req.user.restaurant,
// never a value taken from the URL/body). This is the concrete route
// Phase 3 #14 (ownership isolation) is tested against.
router.get('/:id', protect, restrictToOwnRestaurant, getRestaurantById);

module.exports = router;
