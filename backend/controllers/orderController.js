const prisma = require('../lib/prisma');
const {
  ORDER_STATUSES,
  DINING_TYPES,
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
    diningType: order.diningType || 'DINE_IN',
    tableNumber: order.tableNumber || null,
    status: order.status,
    items: order.items ? order.items.map(serializeOrderItem) : [],
    total: order.totalAmount ? order.totalAmount.toString() : '0',
    totalAmount: order.totalAmount ? order.totalAmount.toString() : '0',
    createdAt: order.createdAt,
    updatedAt: order.updatedAt,
  };
}

async function getOrders(req, res, next) {
  try {
    const { status, diningType, search } = req.query;

    const where = { restaurantId: req.user.restaurantId };
    if (status && status.toUpperCase() !== 'ALL') {
      const upper = status.toUpperCase() === 'CONFIRMED' ? 'ACCEPTED' : status.toUpperCase();
      if (!ORDER_STATUSES.includes(upper)) {
        return res.status(400).json({
          success: false,
          message: `status must be one of: ${ORDER_STATUSES.join(', ')}`,
        });
      }
      where.status = upper;
    }

    if (diningType && diningType.toUpperCase() !== 'ALL') {
      const upperDining = diningType.toUpperCase();
      if (!DINING_TYPES.includes(upperDining)) {
        return res.status(400).json({
          success: false,
          message: `diningType must be one of: ${DINING_TYPES.join(', ')}`,
        });
      }
      where.diningType = upperDining;
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

    const serialized = orders.map(serializeOrder);
    res.status(200).json({
      success: true,
      message: 'Orders fetched successfully',
      data: serialized,
      orders: serialized,
    });
  } catch (err) {
    next(err);
  }
}

async function getOrderById(req, res, next) {
  try {
    const order = await prisma.order.findUnique({
      where: { id: req.params.id },
      include: { items: true },
    });

    if (!order || order.restaurantId !== req.user.restaurantId) {
      return res.status(404).json({ success: false, message: 'Order not found' });
    }

    const serialized = serializeOrder(order);
    res.status(200).json({
      success: true,
      message: 'Order fetched successfully',
      data: serialized,
      order: serialized,
    });
  } catch (err) {
    next(err);
  }
}

async function updateOrderStatus(req, res, next) {
  try {
    const rawStatus = req.body.status;
    const requestedNormalized = rawStatus === 'CONFIRMED' ? 'ACCEPTED' : rawStatus;

    if (!ORDER_STATUSES.includes(requestedNormalized)) {
      return res.status(400).json({
        success: false,
        message: `status must be one of: ${ORDER_STATUSES.join(', ')}`,
      });
    }

    const order = await prisma.order.findUnique({ where: { id: req.params.id } });
    if (!order || order.restaurantId !== req.user.restaurantId) {
      return res.status(404).json({ success: false, message: 'Order not found' });
    }

    if (!isValidTransition(order.status, requestedNormalized)) {
      return res.status(400).json({
        success: false,
        message: `Cannot change status from ${order.status} to ${rawStatus}`,
      });
    }

    const updated = await prisma.order.update({
      where: { id: order.id },
      data: { status: requestedNormalized },
      include: { items: true, restaurant: { select: { name: true } } },
    });

    emitToRestaurant(updated.restaurantId, 'order:status_updated', {
      orderId: updated.id,
      publicOrderReference: updated.publicToken,
      diningType: updated.diningType || 'DINE_IN',
      tableNumber: updated.tableNumber || null,
      status: updated.status,
      updatedAt: updated.updatedAt,
    });
    emitToOrder(updated.publicToken, 'order:status_updated', {
      orderId: updated.publicToken,
      orderNumber: deriveOrderNumber(updated.publicToken),
      restaurantName: updated.restaurant ? updated.restaurant.name : undefined,
      diningType: updated.diningType || 'DINE_IN',
      tableNumber: updated.tableNumber || null,
      status: updated.status,
      items: updated.items.map(serializeOrderItem),
      total: updated.totalAmount.toString(),
      createdAt: updated.createdAt,
    });

    const serialized = serializeOrder(updated);
    if (rawStatus === 'CONFIRMED' && serialized.status === 'ACCEPTED') {
      serialized.status = 'CONFIRMED';
    }

    res.status(200).json({
      success: true,
      message: `Order marked as ${rawStatus}`,
      data: serialized,
      order: serialized,
    });
  } catch (err) {
    next(err);
  }
}

module.exports = { getOrders, getOrderById, updateOrderStatus };
