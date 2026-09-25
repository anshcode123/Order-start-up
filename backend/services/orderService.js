const crypto = require('crypto');
const { Prisma } = require('@prisma/client');
const prisma = require('../lib/prisma');
const { emitToRestaurant } = require('./socketService');
const { sendOrderNotification } = require('./whatsappService');
const { assertActiveSubscription, checkOrderLimit } = require('./subscriptionService');

const TABLE_NUMBER_MAX_LENGTH = 30;
const MAX_QUANTITY_PER_ITEM = 99;

const ORDER_STATUSES = [
  'PENDING',
  'ACCEPTED',
  'PREPARING',
  'READY',
  'COMPLETED',
  'CANCELLED',
  'REJECTED',
];

const ALLOWED_TRANSITIONS = {
  PENDING: ['ACCEPTED', 'REJECTED', 'CANCELLED'],
  ACCEPTED: ['PREPARING', 'CANCELLED'],
  PREPARING: ['READY', 'CANCELLED'],
  READY: ['COMPLETED'],
  COMPLETED: [],
  CANCELLED: [],
  REJECTED: [],
};

function apiError(statusCode, message) {
  const err = new Error(message);
  err.statusCode = statusCode;
  return err;
}

function isValidTransition(from, to) {
  return Boolean(ALLOWED_TRANSITIONS[from] && ALLOWED_TRANSITIONS[from].includes(to));
}

function validateTableNumber(rawValue) {
  if (typeof rawValue !== 'string') {
    throw apiError(400, 'Table number is required');
  }
  const tableNumber = rawValue.trim();
  if (!tableNumber) {
    throw apiError(400, 'Table number is required');
  }
  if (tableNumber.length > TABLE_NUMBER_MAX_LENGTH) {
    throw apiError(400, `Table number must be ${TABLE_NUMBER_MAX_LENGTH} characters or fewer`);
  }
  return tableNumber;
}

function generatePublicToken() {
  return crypto.randomBytes(24).toString('base64url');
}

function deriveOrderNumber(publicToken) {
  return publicToken.slice(0, 4).toUpperCase();
}

function serializeOrderItem(item) {
  return {
    id: item.id,
    menuItemId: item.menuItemId,
    itemName: item.itemName,
    unitPrice: item.unitPrice.toString(),
    quantity: item.quantity,
    subtotal: item.subtotal.toString(),
  };
}

function isDuplicateCart(existingItems, newLines) {
  if (!existingItems || existingItems.length !== newLines.length) return false;
  const sortedExisting = [...existingItems].sort((a, b) =>
    (a.menuItemId || '').localeCompare(b.menuItemId || '')
  );
  const sortedNew = [...newLines].sort((a, b) =>
    (a.menuItemId || '').localeCompare(b.menuItemId || '')
  );

  for (let i = 0; i < sortedExisting.length; i++) {
    if (sortedExisting[i].menuItemId !== sortedNew[i].menuItemId) return false;
    if (sortedExisting[i].quantity !== sortedNew[i].quantity) return false;
  }
  return true;
}

async function createOrderFromCart({ restaurantSlug, tableNumber: rawTableNumber, items }) {
  if (!restaurantSlug || typeof restaurantSlug !== 'string') {
    throw apiError(400, 'restaurantSlug is required');
  }

  const restaurant = await prisma.restaurant.findUnique({ where: { slug: restaurantSlug } });
  if (!restaurant) {
    throw apiError(404, 'Restaurant menu is currently unavailable.');
  }
  if (!restaurant.isActive) {
    throw apiError(403, 'Restaurant menu is currently unavailable.');
  }

  await assertActiveSubscription(restaurant.id);
  await checkOrderLimit(restaurant.id);

  const tableNumber = validateTableNumber(rawTableNumber);

  if (!Array.isArray(items) || items.length === 0) {
    throw apiError(400, 'Your cart is empty');
  }

  for (const line of items) {
    if (!line || typeof line.menuItemId !== 'string' || !line.menuItemId) {
      throw apiError(400, 'Each item must include a valid menuItemId');
    }
    const quantity = Number(line.quantity);
    if (!Number.isInteger(quantity) || quantity < 1) {
      throw apiError(400, 'Each item quantity must be a whole number of at least 1');
    }
    if (quantity > MAX_QUANTITY_PER_ITEM) {
      throw apiError(400, `Quantity per item cannot exceed ${MAX_QUANTITY_PER_ITEM}`);
    }
  }

  const menuItemIds = items.map((line) => line.menuItemId);
  const menuItems = await prisma.menuItem.findMany({ where: { id: { in: menuItemIds } } });
  const menuItemById = new Map(menuItems.map((item) => [item.id, item]));

  const orderLines = items.map((line) => {
    const menuItem = menuItemById.get(line.menuItemId);

    if (!menuItem || menuItem.restaurantId !== restaurant.id) {
      throw apiError(400, 'One or more items are not available from this restaurant.');
    }
    if (!menuItem.isAvailable) {
      throw apiError(400, `${menuItem.name} is currently unavailable.`);
    }

    const quantity = Number(line.quantity);
    const subtotal = menuItem.price.mul(quantity);

    return {
      menuItemId: menuItem.id,
      itemName: menuItem.name,
      unitPrice: menuItem.price,
      quantity,
      subtotal,
    };
  });

  const totalAmount = orderLines.reduce(
    (sum, line) => sum.add(line.subtotal),
    new Prisma.Decimal(0)
  );

  // 5-second duplicate order idempotency protection
  const DUPLICATE_WINDOW_MS = 5000;
  const cutoffTime = new Date(Date.now() - DUPLICATE_WINDOW_MS);

  const recentOrder = await prisma.order.findFirst({
    where: {
      restaurantId: restaurant.id,
      tableNumber,
      createdAt: { gte: cutoffTime },
      status: 'PENDING',
    },
    include: {
      items: true,
      restaurant: {
        select: { name: true, whatsappNumber: true, phone: true },
      },
    },
    orderBy: { createdAt: 'desc' },
  });

  if (recentOrder && isDuplicateCart(recentOrder.items, orderLines)) {
    return recentOrder;
  }

  const order = await prisma.$transaction(async (tx) => {
    const createdOrder = await tx.order.create({
      data: {
        restaurantId: restaurant.id,
        tableNumber,
        status: 'PENDING',
        totalAmount,
        publicToken: generatePublicToken(),
        items: { create: orderLines },
      },
      include: {
        items: true,
        restaurant: {
          select: { name: true, whatsappNumber: true, phone: true },
        },
      },
    });
    return createdOrder;
  });

  const eventPayload = {
    orderId: order.id,
    publicOrderReference: order.publicToken,
    tableNumber: order.tableNumber,
    items: order.items.map(serializeOrderItem),
    totalAmount: order.totalAmount.toString(),
    status: order.status,
    createdAt: order.createdAt,
    order: {
      id: order.id,
      restaurantId: restaurant.id,
      tableNumber: order.tableNumber,
      status: order.status,
      totalAmount: order.totalAmount.toString(),
    },
  };
  emitToRestaurant(restaurant.id, 'order:new', eventPayload);
  emitToRestaurant(restaurant.id, 'new_order', eventPayload);

  try {
    await sendOrderNotification({
      order,
      restaurant: order.restaurant || restaurant,
    });
  } catch (whatsappErr) {
    console.error('[OrderService] WhatsApp notification hook error:', whatsappErr.message);
  }

  return order;
}

module.exports = {
  ORDER_STATUSES,
  ALLOWED_TRANSITIONS,
  isValidTransition,
  validateTableNumber,
  generatePublicToken,
  deriveOrderNumber,
  serializeOrderItem,
  createOrderFromCart,
};
