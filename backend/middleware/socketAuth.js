const { verifyToken } = require('../utils/token');
const prisma = require('../lib/prisma');

/**
 * Socket.IO connection middleware (registered via io.use in lib/socket.js).
 *
 * Unlike the HTTP `protect` middleware, this does NOT reject a
 * connection just because it has no token - Phase 7 customers are
 * always anonymous and never carry a JWT, so "no token" is the normal,
 * expected case for a customer tracking their order (see lib/socket.js
 * for how such a socket is still allowed to join its own
 * order:{publicToken} room).
 *
 * It DOES reject a connection that supplies a token which fails to
 * verify (expired/invalid/inactive user) - presenting a bad token only
 * ever happens for a Restaurant Admin session, so that connection is
 * refused outright rather than silently downgraded to anonymous.
 *
 * On success for a real user, attaches:
 *   socket.data.user = { id, role, restaurantId }
 * restaurantId comes only from the verified, freshly-reloaded user
 * record - never anything the client sends (Phase 7 spec #5, #19).
 */
async function attachSocketUser(socket, next) {
  try {
    const token = socket.handshake.auth && socket.handshake.auth.token;

    if (!token) {
      return next();
    }

    const payload = verifyToken(token);
    const user = await prisma.user.findUnique({ where: { id: payload.id } });

    if (!user || !user.isActive) {
      return next(new Error('Not authenticated'));
    }

    socket.data.user = { id: user.id, role: user.role, restaurantId: user.restaurantId };
    next();
  } catch (err) {
    next(new Error('Not authenticated'));
  }
}

module.exports = { attachSocketUser };
