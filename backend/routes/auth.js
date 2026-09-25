const express = require('express');
const { login, me, logout } = require('../controllers/authController');
const { protect } = require('../middleware/auth');
const { authRateLimiter } = require('../middleware/rateLimiter');

const router = express.Router();

router.post('/login', authRateLimiter, login);
router.post('/logout', logout);
router.get('/me', protect, me);

module.exports = router;
