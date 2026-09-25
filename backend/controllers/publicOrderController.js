const prisma = require('../lib/prisma');
const {
  createOrderFromCart,
  deriveOrderNumber,
  serializeOrderItem,
} = require('../services/orderService');
const { normalizePhoneNumber, formatOrderMessage } = require('../services/whatsappService');

function serializePublicOrder(order) {
  return {
    id: order.id,
    orderId: order.publicToken,
    orderNumber: deriveOrderNumber(order.publicToken),
    restaurantId: order.restaurantId,
    restaurantName: order.restaurant ? order.restaurant.name : undefined,
    tableNumber: order.tableNumber,
    status: order.status,
    items: order.items.map(serializeOrderItem),
    total: order.totalAmount.toString(),
    totalAmount: order.totalAmount.toString(),
    createdAt: order.createdAt,
  };
}

async function createOrder(req, res, next) {
  try {
    const { restaurantSlug, tableNumber, items } = req.body;

    const order = await createOrderFromCart({ restaurantSlug, tableNumber, items });
    const serialized = serializePublicOrder(order);

    let whatsappNotification = null;
    const rawWa = order.restaurant && (order.restaurant.whatsappNumber || order.restaurant.phone);
    const cleanPhone = normalizePhoneNumber(rawWa);
    if (cleanPhone) {
      const msg = formatOrderMessage({
        order,
        restaurantName: order.restaurant ? order.restaurant.name : '',
      });
      whatsappNotification = {
        whatsappUrl: `https://wa.me/${cleanPhone}?text=${encodeURIComponent(msg)}`,
      };
    }

    res.status(201).json({
      success: true,
      message: 'Order placed successfully',
      data: serialized,
      order: serialized,
      whatsappNotification,
    });
  } catch (err) {
    if (err.code === 'P2002') {
      return res.status(409).json({
        success: false,
        message: 'Could not place order - please try again.',
      });
    }
    next(err);
  }
}

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

    const serialized = serializePublicOrder(order);
    res.status(200).json({
      success: true,
      message: 'Order status fetched successfully',
      data: serialized,
      order: serialized,
    });
  } catch (err) {
    next(err);
  }
}

module.exports = { createOrder, getOrderStatus };
