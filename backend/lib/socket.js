const { Server } = require('socket.io');
const { attachSocketUser } = require('../middleware/socketAuth');
const prisma = require('./prisma');

let io;

/**
 * Creates the single shared Socket.IO instance, attached to the same
 * HTTP server Express already listens on (server.js passes its
 * http.createServer(app) instance here - this never spins up a second
 * server). Call once, at startup.
 */
function initializeSocket(server) {
  io = new Server(server, {
    cors: {
      // Same origin config as the REST API's cors() in server.js, for
      // consistency - see that file's comment about CLIENT_ORIGIN.
      origin: process.env.CLIENT_ORIGIN || '*',
      methods: ['GET', 'POST'],
    },
  });

  io.use(attachSocketUser);

  io.on('connection', (socket) => {
    const user = socket.data.user;

    // Restaurant Admin: auto-join their own restaurant's room.
    // restaurantId comes ONLY from the verified JWT (via
    // attachSocketUser) - never anything the client could send over the
    // socket itself (Phase 7 spec #5, #19). SUPER_ADMIN is intentionally
    // not auto-joined to anything here (Phase 7 spec #20).
    if (user && user.role === 'RESTAURANT_ADMIN' && user.restaurantId) {
      socket.join(`restaurant:${user.restaurantId}`);
    }

    // Customer: join the room for one specific order, but only after
    // confirming that publicToken actually maps to a real order - never
    // blindly join whatever room name the client asks for (Phase 7 spec
    // #6, #18). Uses an ack callback so the Flutter client knows
    // definitively whether the subscription succeeded.
    socket.on('order:subscribe', async (payload, ack) => {
      const respond = typeof ack === 'function' ? ack : () => {};

      try {
        const orderToken = payload && payload.orderToken;
        if (!orderToken || typeof orderToken !== 'string') {
          return respond({ success: false, message: 'orderToken is required' });
        }

        const order = await prisma.order.findUnique({ where: { publicToken: orderToken } });
        if (!order) {
          return respond({ success: false, message: 'Order not found' });
        }

        socket.join(`order:${orderToken}`);
        respond({ success: true });
      } catch (err) {
        respond({ success: false, message: 'Could not subscribe to order updates' });
      }
    });

    // No custom disconnect handling needed - Socket.IO automatically
    // removes the socket from every room it joined.
  });

  return io;
}

/** Throws if called before initializeSocket() - same failure style as lib/prisma.js. */
function getIO() {
  if (!io) {
    throw new Error('Socket.IO has not been initialized');
  }
  return io;
}

module.exports = { initializeSocket, getIO };
