const express = require('express');
const { createOrder, getOrderStatus } = require('../controllers/publicOrderController');
const { orderRateLimiter } = require('../middleware/rateLimiter');

const router = express.Router();

router.post('/', orderRateLimiter, createOrder);
router.get('/:orderRef/status', getOrderStatus);

module.exports = router;
