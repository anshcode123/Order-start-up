const bcrypt = require('bcrypt');
const prisma = require('../lib/prisma');
const { signToken } = require('../utils/token');

async function login(req, res, next) {
  try {
    const { email, password } = req.body;

    if (!email || !password) {
      return res.status(400).json({ success: false, message: 'Email and password are required' });
    }

    const user = await prisma.user.findUnique({ where: { email: String(email).toLowerCase() } });

    if (!user || !user.isActive) {
      return res.status(401).json({ success: false, message: 'Invalid email or password' });
    }

    const passwordMatches = await bcrypt.compare(password, user.password);
    if (!passwordMatches) {
      return res.status(401).json({ success: false, message: 'Invalid email or password' });
    }

    if (user.role === 'RESTAURANT_ADMIN' && user.restaurantId) {
      const restaurant = await prisma.restaurant.findUnique({ where: { id: user.restaurantId } });
      if (!restaurant || !restaurant.isActive) {
        return res.status(403).json({
          success: false,
          message: 'Your restaurant account is currently inactive. Please contact support.',
        });
      }
    }

    const token = signToken({ id: user.id, role: user.role, restaurant: user.restaurantId });

    res.status(200).json({
      success: true,
      token,
      user: {
        id: user.id,
        name: user.name,
        email: user.email,
        role: user.role,
        restaurant: user.restaurantId,
        restaurantId: user.restaurantId,
      },
    });
  } catch (err) {
    next(err);
  }
}

async function me(req, res, next) {
  try {
    const responseUser = {
      id: req.user.id,
      name: req.user.name,
      email: req.user.email,
      role: req.user.role,
      restaurant: null,
      restaurantId: req.user.restaurantId || null,
    };

    if (req.user.role === 'RESTAURANT_ADMIN' && req.user.restaurant) {
      const restaurant = await prisma.restaurant.findUnique({ where: { id: req.user.restaurant } });
      if (restaurant) {
        responseUser.restaurant = {
          id: restaurant.id,
          name: restaurant.name,
        };
      }
    }

    res.status(200).json({ success: true, user: responseUser });
  } catch (err) {
    next(err);
  }
}

async function logout(req, res) {
  res.status(200).json({
    success: true,
    message: 'Logged out successfully',
  });
}

module.exports = { login, me, logout };
