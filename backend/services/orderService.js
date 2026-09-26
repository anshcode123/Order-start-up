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
  'CANCELLED',
  'REJECTED',
];

const ALLOWED_TRANSITIONS = {
  PENDING: ['ACCEPTED', 'REJECTED', 'CANCELLED'],
  ACCEPTED: ['PREPARING', 'CANCELLED'],
  PREPARING: ['READY', 'CANCELLED'],
  READY: [],
  CANCELLED: [],
  REJECTED: [],
};

const DINING_TYPES = ['DINE_IN', 'TAKEAWAY'];

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

function resolveDiningAndTable({ rawDiningType, rawTableNumber, requireTableNumber }) {
  let diningType = 'DINE_IN';
  if (rawDiningType !== undefined && rawDiningType !== null && String(rawDiningType).trim() !== '') {
    const normalized = String(rawDiningType).trim().toUpperCase();
    if (!DINING_TYPES.includes(normalized)) {
      throw apiError(400, `diningType must be one of: ${DINING_TYPES.join(', ')}`);
    }
    diningType = normalized;
  }

  if (diningType === 'TAKEAWAY') {
    return { diningType: 'TAKEAWAY', tableNumber: null };
  }

  // DINE_IN
  const trimmedTable = typeof rawTableNumber === 'string' ? rawTableNumber.trim() : '';
  if (trimmedTable.length > TABLE_NUMBER_MAX_LENGTH) {
    throw apiError(400, `Table number must be ${TABLE_NUMBER_MAX_LENGTH} characters or fewer`);
  }

  const mustHaveTable = requireTableNumber === undefined ? true : Boolean(requireTableNumber);
  if (mustHaveTable && !trimmedTable) {
    throw apiError(400, 'Table number is required for Dine In orders');
  }

  return {
    diningType: 'DINE_IN',
    tableNumber: trimmedTable || null,
  };
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
    variantId: item.variantId || null,
    variantName: item.variantName || null,
    unitPrice: item.unitPrice.toString(),
    quantity: item.quantity,
    subtotal: item.subtotal.toString(),
  };
}

function lineSignature(item) {
  return `${item.menuItemId || ''}::${item.variantId || ''}::${item.variantName || ''}`;
}

function isDuplicateCart(existingItems, newLines) {
  if (!existingItems || existingItems.length !== newLines.length) return false;
  const sortedExisting = [...existingItems].sort((a, b) =>
    lineSignature(a).localeCompare(lineSignature(b))
  );
  const sortedNew = [...newLines].sort((a, b) =>
    lineSignature(a).localeCompare(lineSignature(b))
  );

  for (let i = 0; i < sortedExisting.length; i++) {
    if (sortedExisting[i].menuItemId !== sortedNew[i].menuItemId) return false;
    if ((sortedExisting[i].variantId || null) !== (sortedNew[i].variantId || null)) return false;
    if ((sortedExisting[i].variantName || null) !== (sortedNew[i].variantName || null)) return false;
    if (sortedExisting[i].quantity !== sortedNew[i].quantity) return false;
  }
  return true;
}

async function createOrderFromCart({
  restaurantSlug,
  diningType: rawDiningType,
  tableNumber: rawTableNumber,
  items,
}) {
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

  const { diningType, tableNumber } = resolveDiningAndTable({
    rawDiningType,
    rawTableNumber,
    requireTableNumber: restaurant.requireTableNumber,
  });

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

  const menuItemIds = [...new Set(items.map((line) => line.menuItemId))];
  const menuItems = await prisma.menuItem.findMany({
    where: { id: { in: menuItemIds } },
    include: { variants: true },
  });
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
    const hasVariantIdInput =
      line.variantId !== undefined && line.variantId !== null && String(line.variantId).trim() !== '';
    const hasVariantNameInput =
      line.variantName !== undefined && line.variantName !== null && String(line.variantName).trim() !== '';

    let unitPrice = menuItem.price;
    let resolvedVariantId = null;
    let resolvedVariantName = null;

    if (menuItem.hasVariants) {
      if (!hasVariantIdInput && !hasVariantNameInput) {
        throw apiError(400, `Please select Half or Full for ${menuItem.name}.`);
      }

      const itemVariants = Array.isArray(menuItem.variants) ? menuItem.variants : [];
      let matchedVariant = null;

      if (hasVariantIdInput) {
        matchedVariant = itemVariants.find((v) => v.id === String(line.variantId).trim());
      } else if (hasVariantNameInput) {
        const targetName = String(line.variantName).trim().toLowerCase();
        matchedVariant = itemVariants.find((v) => v.name.toLowerCase() === targetName);
      }

      if (!matchedVariant || matchedVariant.menuItemId !== menuItem.id) {
        throw apiError(400, `Invalid variant selected for ${menuItem.name}.`);
      }
      if (!matchedVariant.isAvailable) {
        throw apiError(400, `${menuItem.name} (${matchedVariant.name}) is currently unavailable.`);
      }

      unitPrice = matchedVariant.price;
      resolvedVariantId = matchedVariant.id;
      resolvedVariantName = matchedVariant.name;
    } else {
      if (hasVariantIdInput || hasVariantNameInput) {
        throw apiError(400, `${menuItem.name} does not support size variants.`);
      }
    }

    const subtotal = unitPrice.mul(quantity);

    return {
      menuItemId: menuItem.id,
      itemName: menuItem.name,
      variantId: resolvedVariantId,
      variantName: resolvedVariantName,
      unitPrice,
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
      diningType,
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
        diningType,
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
    orderNumber: deriveOrderNumber(order.publicToken),
    diningType: order.diningType,
    tableNumber: order.tableNumber,
    items: order.items.map(serializeOrderItem),
    totalAmount: order.totalAmount.toString(),
    status: order.status,
    createdAt: order.createdAt,
    order: {
      id: order.id,
      restaurantId: restaurant.id,
      diningType: order.diningType,
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
  DINING_TYPES,
  isValidTransition,
  validateTableNumber,
  resolveDiningAndTable,
  generatePublicToken,
  deriveOrderNumber,
  serializeOrderItem,
  createOrderFromCart,
};
