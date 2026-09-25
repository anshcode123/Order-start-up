const { Server } = require('socket.io');
const { attachSocketUser } = require('../middleware/socketAuth');
const { buildCorsOriginValidator } = require('../config/cors');
const prisma = require('./prisma');

let io;

function initializeSocket(server) {
  io = new Server(server, {
    cors: {
      origin: buildCorsOriginValidator(),
      credentials: true,
      methods: ['GET', 'POST'],
    },
  });

  io.use(attachSocketUser);

  io.on('connection', (socket) => {
    const user = socket.data.user;

    if (user && user.role === 'RESTAURANT_ADMIN' && user.restaurantId) {
      socket.join(`restaurant:${user.restaurantId}`);
    }

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
  });

  return io;
}

function getIO() {
  if (!io) {
    throw new Error('Socket.IO has not been initialized');
  }
  return io;
}

module.exports = { initializeSocket, getIO };
