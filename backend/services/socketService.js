const { getIO } = require('../lib/socket');

/**
 * Deliberately dumb - no business logic, no payload-building. Callers
 * (orderService.js, orderController.js) build the event payload
 * themselves and pass it straight through; this only knows the room
 * naming convention. Kept separate from lib/socket.js so the low-level
 * connection/auth setup stays isolated from "what an order event
 * contains".
 *
 * Both functions swallow their own errors (logging only) - a failed
 * broadcast must never turn an already-successful database write into
 * a failed HTTP response. REST/Postgres remains the source of truth;
 * Socket.IO is best-effort delivery on top of it (Phase 7 spec #15).
 */
function emitToRestaurant(restaurantId, event, payload) {
  try {
    getIO().to(`restaurant:${restaurantId}`).emit(event, payload);
  } catch (err) {
    console.error(`Socket emit to restaurant:${restaurantId} (${event}) failed:`, err.message);
  }
}

function emitToOrder(publicToken, event, payload) {
  try {
    getIO().to(`order:${publicToken}`).emit(event, payload);
  } catch (err) {
    console.error(`Socket emit to order:${publicToken} (${event}) failed:`, err.message);
  }
}

module.exports = { emitToRestaurant, emitToOrder };
