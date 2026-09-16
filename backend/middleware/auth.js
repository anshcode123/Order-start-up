const jwt = require('jsonwebtoken');
const User = require('../models/User');

/**
 * Protect routes - verifies JWT from Authorization header
 */
async function protect(req, res, next) {
  let token;

  if (
    req.headers.authorization &&
    req.headers.authorization.startsWith('Bearer')
  ) {
    token = req.headers.authorization.split(' ')[1];
  }

  if (!token) {
    return res.status(401).json({
      success: false,
      message: 'Not authorized to access this route, token missing',
    });
  }

  try {
    const decoded = jwt.verify(token, process.env.JWT_SECRET || 'scanserve_jwt_secret_key_2026_super_secure');

    const user = await User.findById(decoded.id).select('-password');
    if (!user) {
      return res.status(401).json({
        success: false,
        message: 'Not authorized, user not found',
      });
    }

    req.user = user;
    next();
  } catch (err) {
    return res.status(401).json({
      success: false,
      message: 'Not authorized, invalid or expired token',
    });
  }
}

/**
 * Role middleware - SUPER_ADMIN only
 */
function requireSuperAdmin(req, res, next) {
  if (req.user && req.user.role === 'SUPER_ADMIN') {
    return next();
  }
  return res.status(403).json({
    success: false,
    message: 'Access denied: Super Admin role required',
  });
}

/**
 * Role middleware - RESTAURANT_ADMIN only
 */
function requireRestaurantAdmin(req, res, next) {
  if (req.user && req.user.role === 'RESTAURANT_ADMIN') {
    return next();
  }
  return res.status(403).json({
    success: false,
    message: 'Access denied: Restaurant Admin role required',
  });
}

module.exports = {
  protect,
  requireSuperAdmin,
  requireRestaurantAdmin,
};

