const { verifyToken } = require('../utils/token');
const prisma = require('../lib/prisma');

/**
 * Verifies the Bearer token and attaches the authenticated user to
 * req.user. Loads the user fresh from the DB (rather than trusting the
 * token payload alone) so a deactivated/deleted user is rejected even
 * with a still-valid token.
 *
 * req.user ends up with: id, name, email, role, restaurant, isActive
 * (restaurant is the restaurant id string, or null - not populated here).
 * NOTE: Prisma's column is `restaurantId` - it's normalized to
 * `restaurant` here so every downstream consumer (restaurantAccess.js,
 * controllers, etc.) keeps working unchanged after the Mongo -> Postgres
 * migration.
 */
async function protect(req, res, next) {
  try {
    const header = req.headers.authorization || '';
    const [scheme, token] = header.split(' ');

    if (scheme !== 'Bearer' || !token) {
      return res.status(401).json({ success: false, message: 'Not authenticated' });
    }

    const payload = verifyToken(token);

    const user = await prisma.user.findUnique({ where: { id: payload.id } });

    if (!user || !user.isActive) {
      return res.status(401).json({ success: false, message: 'Not authenticated' });
    }

    req.user = { ...user, restaurant: user.restaurantId };
    next();
  } catch (err) {
    return res.status(401).json({ success: false, message: 'Not authenticated' });
  }
}

/**
 * Restricts a route to one or more roles. Use AFTER protect().
 *   router.get('/x', protect, authorize('SUPER_ADMIN'), handler)
 */
function authorize(...roles) {
  return (req, res, next) => {
    if (!req.user || !roles.includes(req.user.role)) {
      return res.status(403).json({ success: false, message: 'Forbidden' });
    }
    next();
  };
}

module.exports = { protect, authorize };
