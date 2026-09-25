const prisma = require('../lib/prisma');
const { verifyToken } = require('../utils/token');

async function protect(req, res, next) {
  try {
    const authHeader = req.headers.authorization;
    if (!authHeader || !authHeader.startsWith('Bearer ')) {
      return res.status(401).json({ success: false, message: 'Not authorized, token missing' });
    }

    const token = authHeader.split(' ')[1];
    if (!token) {
      return res.status(401).json({ success: false, message: 'Not authorized, token missing' });
    }

    const decoded = verifyToken(token);

    const user = await prisma.user.findUnique({ where: { id: decoded.id } });
    if (!user || !user.isActive) {
      return res.status(401).json({ success: false, message: 'User no longer active or not found' });
    }

    if (user.role === 'RESTAURANT_ADMIN' && user.restaurantId) {
      const restaurant = await prisma.restaurant.findUnique({
        where: { id: user.restaurantId },
        select: { isActive: true },
      });
      if (!restaurant || !restaurant.isActive) {
        return res.status(403).json({
          success: false,
          message: 'Restaurant account is inactive',
        });
      }
    }

    req.user = {
      id: user.id,
      name: user.name,
      email: user.email,
      role: user.role,
      restaurant: user.restaurantId,
      restaurantId: user.restaurantId,
    };
    next();
  } catch (err) {
    return res.status(401).json({ success: false, message: 'Not authorized, token invalid or expired' });
  }
}

function authorize(...roles) {
  return (req, res, next) => {
    if (!req.user || !roles.includes(req.user.role)) {
      return res.status(403).json({ success: false, message: 'Forbidden: insufficient permissions' });
    }
    next();
  };
}

module.exports = { protect, authorize };
