const express = require('express');
const { getOrders, getOrderById, updateOrderStatus } = require('../controllers/orderController');
const { protect, authorize } = require('../middleware/auth');

const router = express.Router();

router.use(protect, authorize('RESTAURANT_ADMIN'));

router.get('/', getOrders);
router.get('/:id', getOrderById);
router.patch('/:id/status', updateOrderStatus);

module.exports = router;
