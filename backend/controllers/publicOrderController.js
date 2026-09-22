const prisma = require('../lib/prisma');
const {
  createOrderFromCart,
  deriveOrderNumber,
  serializeOrderItem,
} = require('../services/orderService');

/**
 * Shape shared by both public endpoints. Deliberately excludes anything
 * about the restaurant beyond its name, and NEVER includes the internal
 * database id - `orderId` here is actually the securely-random
 * publicToken (Phase 6 spec #17).
 */
function serializePublicOrder(order) {
  return {
    orderId: order.publicToken,
    orderNumber: deriveOrderNumber(order.publicToken),
    restaurantName: order.restaurant ? order.restaurant.name : undefined,
    tableNumber: order.tableNumber,
    status: order.status,
    items: order.items.map(serializeOrderItem),
    total: order.totalAmount.toString(),
    createdAt: order.createdAt,
  };
}

// POST /api/public/orders
// No auth - the customer is always anonymous. restaurantId, item names,
// prices, and the total are never taken from the request body; see
// services/orderService.js for where each is re-derived from Postgres.
async function createOrder(req, res, next) {
  try {
    const { restaurantSlug, tableNumber, items } = req.body;

    const order = await createOrderFromCart({ restaurantSlug, tableNumber, items });

    res.status(201).json({
      success: true,
      message: 'Order placed successfully',
      data: serializePublicOrder(order),
    });
  } catch (err) {
    // Astronomically unlikely (24 random bytes per token), but a
    // publicToken collision would surface as a Postgres unique
    // violation - give a clean retryable error instead of a raw 500.
    if (err.code === 'P2002') {
      return res.status(409).json({
        success: false,
        message: 'Could not place order - please try again.',
      });
    }
    next(err);
  }
}

// GET /api/public/orders/:orderRef/status
// :orderRef is the publicToken, never the internal id - looking up by
// the wrong field on purpose is what keeps this endpoint from being
// usable to enumerate other customers' orders (Phase 6 spec #16, #17).
async function getOrderStatus(req, res, next) {
  try {
    const { orderRef } = req.params;

    const order = await prisma.order.findUnique({
      where: { publicToken: orderRef },
      include: { items: true, restaurant: { select: { name: true } } },
    });

    if (!order) {
      return res.status(404).json({ success: false, message: 'Order not found' });
    }

    res.status(200).json({
      success: true,
      message: 'Order status fetched successfully',
      data: serializePublicOrder(order),
    });
  } catch (err) {
    next(err);
  }
}

module.exports = { createOrder, getOrderStatus };
