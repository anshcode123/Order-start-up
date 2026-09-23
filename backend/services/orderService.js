const crypto = require('crypto');
const { Prisma } = require('@prisma/client');
const prisma = require('../lib/prisma');
const { emitToRestaurant } = require('./socketService');
const { sendOrderNotification } = require('./whatsappService');

const TABLE_NUMBER_MAX_LENGTH = 30;
const MAX_QUANTITY_PER_ITEM = 999; // defensive cap, not a business rule

const ORDER_STATUSES = [
  'PENDING',
  'ACCEPTED',
  'PREPARING',
  'READY',
  'COMPLETED',
  'CANCELLED',
  'REJECTED',
];

// What each status is allowed to move to next. COMPLETED/CANCELLED/
// REJECTED are terminal - this is what stops something like
// COMPLETED -> PREPARING (Phase 6 spec #14).
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

/** Trims and validates a customer-supplied table number. Always a String. */
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

/**
 * A secure, unguessable reference for the public order-status endpoint -
 * deliberately separate from the internal `id` (Phase 6 spec #17).
 * base64url keeps it URL-safe with no padding characters to escape.
 */
function generatePublicToken() {
  return crypto.randomBytes(24).toString('base64url');
}

/** Short label for display only ("Order #A8F2") - never used for lookups. */
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

/**
 * Creates an Order + its OrderItems from raw, untrusted client input.
 * Every price, name, and the restaurant itself is re-derived from
 * PostgreSQL - nothing from `items` except menuItemId/quantity is ever
 * trusted (Phase 6 spec #5, #6, #22, #23).
 *
 * Throws an Error with .statusCode set on any validation failure; the
 * whole Order+OrderItems write happens in a single Prisma transaction,
 * so a failure partway through never leaves a partial order behind.
 */
async function createOrderFromCart({ restaurantSlug, tableNumber: rawTableNumber, items }) {
  if (!restaurantSlug || typeof restaurantSlug !== 'string') {
    throw apiError(400, 'restaurantSlug is required');
  }

  const restaurant = await prisma.restaurant.findUnique({ where: { slug: restaurantSlug } });
  // Same 404 message style as the public menu endpoint - a disabled
  // restaurant must not be distinguishable from a nonexistent one.
  if (!restaurant || !restaurant.isActive) {
    throw apiError(404, 'Restaurant menu is currently unavailable.');
  }

  const tableNumber = validateTableNumber(rawTableNumber);

  if (!Array.isArray(items) || items.length === 0) {
    throw apiError(400, 'Your cart is empty');
  }

  // Basic shape validation before touching the database.
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

  // Build order lines from CURRENT database state only - price and name
  // are never taken from the request (Phase 6 spec #23).
  const orderLines = items.map((line) => {
    const menuItem = menuItemById.get(line.menuItemId);

    if (!menuItem || menuItem.restaurantId !== restaurant.id) {
      // Same message whether the id doesn't exist at all or belongs to
      // a different restaurant - never confirm another restaurant's
      // menu item exists.
      throw apiError(400, 'One or more items are not available from this restaurant.');
    }
    if (!menuItem.isAvailable) {
      throw apiError(400, `${menuItem.name} is currently unavailable.`);
    }

    const quantity = Number(line.quantity);
    // Decimal arithmetic via the Prisma Decimal the item already came
    // with - never coerced through a JS float.
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

  // Emit ONLY after the transaction has committed (Phase 7 spec #7) -
  // never before, and never if the transaction throws above.
  emitToRestaurant(restaurant.id, 'order:new', {
    orderId: order.id,
    publicOrderReference: order.publicToken,
    tableNumber: order.tableNumber,
    items: order.items.map(serializeOrderItem),
    totalAmount: order.totalAmount.toString(),
    status: order.status,
    createdAt: order.createdAt,
  });

  // Phase 8: WhatsApp Order Notification
  // Completely isolated from order creation - any WhatsApp failure,
  // network timeout, or missing credentials will never roll back or fail the order.
  try {
    await sendOrderNotification({
      order,
      restaurant: order.restaurant || restaurant,
    });
  } catch (whatsappErr) {
    console.error('WhatsApp notification dispatch error:', whatsappErr.message);
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
  apiError,
};
