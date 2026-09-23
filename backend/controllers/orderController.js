const prisma = require('../lib/prisma');
const {
  ORDER_STATUSES,
  isValidTransition,
  serializeOrderItem,
  deriveOrderNumber,
} = require('../services/orderService');
const { emitToRestaurant, emitToOrder } = require('../services/socketService');

function serializeOrder(order) {
  return {
    id: order.id,
    publicToken: order.publicToken,
    orderNumber: deriveOrderNumber(order.publicToken),
    tableNumber: order.tableNumber,
    status: order.status,
    items: order.items ? order.items.map(serializeOrderItem) : [],
    total: order.totalAmount ? order.totalAmount.toString() : '0',
    createdAt: order.createdAt,
    updatedAt: order.updatedAt,
  };
}

// GET /api/restaurant/orders
// Optional ?status=PENDING filter and ?search= query.
// Always scoped to the caller's own restaurant via req.user.restaurantId.
async function getOrders(req, res, next) {
  try {
    const { status, search } = req.query;

    const where = { restaurantId: req.user.restaurantId };
    if (status && status.toUpperCase() !== 'ALL') {
      const upper = status.toUpperCase();
      if (!ORDER_STATUSES.includes(upper)) {
        return res.status(400).json({
          success: false,
          message: `status must be one of: ${ORDER_STATUSES.join(', ')}`,
        });
      }
      where.status = upper;
    }

    if (search && typeof search === 'string') {
      const q = search.trim();
      if (q) {
        where.OR = [
          { tableNumber: { contains: q, mode: 'insensitive' } },
          { publicToken: { contains: q, mode: 'insensitive' } },
        ];
      }
    }

    const orders = await prisma.order.findMany({
      where,
      include: { items: true },
      orderBy: { createdAt: 'desc' },
    });

    res.status(200).json({
      success: true,
      message: 'Orders fetched successfully',
      data: orders.map(serializeOrder),
    });
  } catch (err) {
    next(err);
  }
}


// GET /api/restaurant/orders/:id
async function getOrderById(req, res, next) {
  try {
    const order = await prisma.order.findUnique({
      where: { id: req.params.id },
      include: { items: true },
    });

    // Same 404 whether the order doesn't exist or belongs to a
    // different restaurant - never confirm another restaurant's order
    // id is valid (Phase 6 spec #21).
    if (!order || order.restaurantId !== req.user.restaurantId) {
      return res.status(404).json({ success: false, message: 'Order not found' });
    }

    res.status(200).json({
      success: true,
      message: 'Order fetched successfully',
      data: serializeOrder(order),
    });
  } catch (err) {
    next(err);
  }
}

// PATCH /api/restaurant/orders/:id/status
async function updateOrderStatus(req, res, next) {
  try {
    const { status: nextStatus } = req.body;

    if (!ORDER_STATUSES.includes(nextStatus)) {
      return res.status(400).json({
        success: false,
        message: `status must be one of: ${ORDER_STATUSES.join(', ')}`,
      });
    }

    const order = await prisma.order.findUnique({ where: { id: req.params.id } });
    if (!order || order.restaurantId !== req.user.restaurantId) {
      return res.status(404).json({ success: false, message: 'Order not found' });
    }

    if (!isValidTransition(order.status, nextStatus)) {
      return res.status(400).json({
        success: false,
        message: `Cannot change status from ${order.status} to ${nextStatus}`,
      });
    }

    const updated = await prisma.order.update({
      where: { id: order.id },
      data: { status: nextStatus },
      include: { items: true, restaurant: { select: { name: true } } },
    });

    // Emit ONLY after the DB write succeeds (Phase 7 spec #9, #17).
    // Restaurant dashboard gets an admin-shaped payload (real internal
    // id is fine - it's already authenticated and scoped to its own
    // restaurant); the customer's order room gets the same public shape
    // the REST status endpoint returns, so the Flutter side can reuse
    // one model for both.
    emitToRestaurant(updated.restaurantId, 'order:status_updated', {
      orderId: updated.id,
      publicOrderReference: updated.publicToken,
      status: updated.status,
      updatedAt: updated.updatedAt,
    });
    emitToOrder(updated.publicToken, 'order:status_updated', {
      orderId: updated.publicToken,
      orderNumber: deriveOrderNumber(updated.publicToken),
      restaurantName: updated.restaurant ? updated.restaurant.name : undefined,
      tableNumber: updated.tableNumber,
      status: updated.status,
      items: updated.items.map(serializeOrderItem),
      total: updated.totalAmount.toString(),
      createdAt: updated.createdAt,
    });

    res.status(200).json({
      success: true,
      message: `Order marked as ${nextStatus}`,
      data: serializeOrder(updated),
    });
  } catch (err) {
    next(err);
  }
}

module.exports = { getOrders, getOrderById, updateOrderStatus };
