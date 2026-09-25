const { Prisma } = require('@prisma/client');
const prisma = require('../lib/prisma');
const { DEFAULT_TRIAL_DAYS, DEFAULT_PLAN_NAME } = require('../config/subscription');

const DEFAULT_PLANS = [
  {
    name: 'FREE',
    description: 'Free Starter Plan for small kiosks and test menus',
    price: new Prisma.Decimal('0.00'),
    billingInterval: 'MONTHLY',
    maxMenuItems: 20,
    maxCategories: 5,
    maxOrdersPerMonth: 100,
    isActive: true,
  },
  {
    name: 'BASIC',
    description: 'Essential plan for standard cafes and restaurants',
    price: new Prisma.Decimal('499.00'),
    billingInterval: 'MONTHLY',
    maxMenuItems: 100,
    maxCategories: 15,
    maxOrdersPerMonth: 500,
    isActive: true,
  },
  {
    name: 'PRO',
    description: 'Full-scale unlimited plan for high-volume dining',
    price: new Prisma.Decimal('1499.00'),
    billingInterval: 'MONTHLY',
    maxMenuItems: null,
    maxCategories: null,
    maxOrdersPerMonth: null,
    isActive: true,
  },
];

async function seedDefaultPlans() {
  for (const plan of DEFAULT_PLANS) {
    await prisma.subscriptionPlan.upsert({
      where: { name: plan.name },
      update: {
        maxMenuItems: plan.maxMenuItems,
        maxCategories: plan.maxCategories,
      },
      create: plan,
    });
  }
}

async function createTrialSubscription(restaurantId, tx, { planId } = {}) {
  const client = tx || prisma;

  let plan;
  if (planId) {
    plan = await client.subscriptionPlan.findUnique({ where: { id: planId } });
  }
  if (!plan) {
    plan = await client.subscriptionPlan.findFirst({
      where: { name: DEFAULT_PLAN_NAME, isActive: true },
    });
  }
  if (!plan) {
    plan = await client.subscriptionPlan.findFirst({
      where: { isActive: true },
    });
  }
  if (!plan) {
    plan = await client.subscriptionPlan.create({
      data: DEFAULT_PLANS[0],
    });
  }

  const now = new Date();
  const trialEndDate = new Date(now.getTime() + DEFAULT_TRIAL_DAYS * 24 * 60 * 60 * 1000);

  return client.subscription.create({
    data: {
      restaurantId,
      planId: plan.id,
      status: 'TRIAL',
      startDate: now,
      endDate: trialEndDate,
      trialStartDate: now,
      trialEndDate,
    },
    include: { plan: true },
  });
}

async function ensureRestaurantSubscription(restaurantId, tx) {
  const client = tx || prisma;
  let sub = await client.subscription.findUnique({
    where: { restaurantId },
    include: { plan: true },
  });

  if (!sub) {
    sub = await createTrialSubscription(restaurantId, client);
  }
  return sub;
}

async function getEvaluatedSubscription(restaurantId, tx) {
  const client = tx || prisma;
  let sub = await ensureRestaurantSubscription(restaurantId, client);

  const now = new Date();
  let status = sub.status;
  let shouldUpdateStatus = false;

  if (status === 'TRIAL') {
    const expiry = sub.endDate || sub.trialEndDate;
    if (expiry && expiry < now) {
      status = 'EXPIRED';
      shouldUpdateStatus = true;
    }
  } else if (status === 'ACTIVE') {
    if (sub.endDate && sub.endDate < now) {
      status = 'EXPIRED';
      shouldUpdateStatus = true;
    }
  }

  if (shouldUpdateStatus) {
    sub = await client.subscription.update({
      where: { id: sub.id },
      data: { status },
      include: { plan: true },
    });
  }

  const startOfMonth = new Date(now.getFullYear(), now.getMonth(), 1, 0, 0, 0, 0);
  const endOfMonth = new Date(now.getFullYear(), now.getMonth() + 1, 0, 23, 59, 59, 999);

  const [menuItemCount, categoryCount, ordersThisMonth] = await Promise.all([
    client.menuItem.count({ where: { restaurantId } }),
    client.category.count({ where: { restaurantId } }),
    client.order.count({
      where: {
        restaurantId,
        createdAt: { gte: startOfMonth, lte: endOfMonth },
        status: { notIn: ['CANCELLED', 'REJECTED'] },
      },
    }),
  ]);

  let daysRemaining = null;
  const targetDate = status === 'TRIAL' ? (sub.trialEndDate || sub.endDate) : sub.endDate;
  if (targetDate) {
    const diffMs = targetDate.getTime() - now.getTime();
    daysRemaining = Math.max(0, Math.ceil(diffMs / (1000 * 60 * 60 * 24)));
  }

  return {
    subscription: sub,
    plan: sub.plan,
    usage: {
      menuItemCount,
      categoryCount,
      categoriesUsed: categoryCount,
      menuItemsUsed: menuItemCount,
      maxCategories: sub.plan ? sub.plan.maxCategories : null,
      maxMenuItems: sub.plan ? sub.plan.maxMenuItems : null,
      ordersThisMonth,
      daysRemaining,
    },
  };
}

async function assertActiveSubscription(restaurantId) {
  const { subscription } = await getEvaluatedSubscription(restaurantId);
  const status = subscription.status;
  if (status !== 'ACTIVE' && status !== 'TRIAL') {
    const err = new Error('This restaurant is currently unavailable for online ordering.');
    err.statusCode = 403;
    throw err;
  }
  return subscription;
}

async function checkMenuItemLimit(restaurantId) {
  const { plan, usage } = await getEvaluatedSubscription(restaurantId);
  if (plan.maxMenuItems !== null && plan.maxMenuItems !== undefined) {
    if (usage.menuItemCount >= plan.maxMenuItems) {
      const err = new Error('You have reached the maximum number of menu items for your current plan.');
      err.statusCode = 403;
      throw err;
    }
  }
}

async function checkCategoryLimit(restaurantId) {
  const { plan, usage } = await getEvaluatedSubscription(restaurantId);
  if (plan.maxCategories !== null && plan.maxCategories !== undefined) {
    if (usage.categoryCount >= plan.maxCategories) {
      const err = new Error('You have reached the maximum number of categories for your current plan.');
      err.statusCode = 403;
      throw err;
    }
  }
}

async function checkOrderLimit(restaurantId) {
  const { plan, usage } = await getEvaluatedSubscription(restaurantId);
  if (plan.maxOrdersPerMonth !== null && plan.maxOrdersPerMonth !== undefined) {
    if (usage.ordersThisMonth >= plan.maxOrdersPerMonth) {
      const err = new Error('Monthly order limit reached for this restaurant.');
      err.statusCode = 403;
      throw err;
    }
  }
}

module.exports = {
  DEFAULT_PLANS,
  seedDefaultPlans,
  createTrialSubscription,
  ensureRestaurantSubscription,
  getEvaluatedSubscription,
  assertActiveSubscription,
  checkMenuItemLimit,
  checkCategoryLimit,
  checkOrderLimit,
};
