const bcrypt = require('bcrypt');
const prisma = require('../lib/prisma');
const { signToken } = require('../utils/token');

// POST /api/auth/login
async function login(req, res, next) {
  try {
    const { email, password } = req.body;

    if (!email || !password) {
      return res.status(400).json({ success: false, message: 'Email and password are required' });
    }

    const user = await prisma.user.findUnique({ where: { email: String(email).toLowerCase() } });

    // Same generic message whether the email doesn't exist or the
    // password is wrong, so login can't be used to enumerate accounts.
    if (!user || !user.isActive) {
      return res.status(401).json({ success: false, message: 'Invalid email or password' });
    }

    const passwordMatches = await bcrypt.compare(password, user.password);
    if (!passwordMatches) {
      return res.status(401).json({ success: false, message: 'Invalid email or password' });
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
      },
    });
  } catch (err) {
    next(err);
  }
}

// GET /api/auth/me
// Returns the logged-in user's profile. For a RESTAURANT_ADMIN this also
// includes their restaurant's name - this is what both dashboards read
// from, so there's no separate "restaurant admin dashboard" endpoint.
async function me(req, res, next) {
  try {
    const responseUser = {
      id: req.user.id,
      name: req.user.name,
      email: req.user.email,
      role: req.user.role,
      restaurant: null,
    };

    if (req.user.role === 'RESTAURANT_ADMIN' && req.user.restaurant) {
      const restaurant = await prisma.restaurant.findUnique({ where: { id: req.user.restaurant } });
      if (restaurant) {
        responseUser.restaurant = {
          id: restaurant.id,
          name: restaurant.name,
          slug: restaurant.slug,
          isActive: restaurant.isActive,
        };
      }
    }

    res.status(200).json({ success: true, user: responseUser });
  } catch (err) {
    next(err);
  }
}

module.exports = { login, me };
