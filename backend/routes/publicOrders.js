const express = require('express');
const { createOrder, getOrderStatus } = require('../controllers/publicOrderController');

const router = express.Router();

// Intentionally no protect()/authorize() - customers are always
// anonymous (Phase 6 spec). restaurantId/price/name are never trusted
// from the client; see services/orderService.js.
router.post('/', createOrder);
router.get('/:orderRef/status', getOrderStatus);

module.exports = router;
