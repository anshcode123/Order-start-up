const prisma = require('../lib/prisma');
const { SUBSCRIPTION_STATUSES } = require('../config/subscription');
const { getEvaluatedSubscription } = require('../services/subscriptionService');

function serializeEvaluatedSubscription({ subscription, plan, usage, restaurant }) {
  const priceStr = plan ? plan.price.toString() : '0';
  return {
    id: subscription.id,
    restaurantId: subscription.restaurantId,
    restaurant: restaurant
      ? {
          id: restaurant.id,
          name: restaurant.name,
          slug: restaurant.slug,
          email: restaurant.email,
          phone: restaurant.phone,
          isActive: restaurant.isActive,
        }
      : undefined,
    planId: subscription.planId,
    plan: plan
      ? {
          id: plan.id,
          name: plan.name,
          description: plan.description,
          price: priceStr,
          priceMonthly: priceStr,
          billingInterval: plan.billingInterval,
          maxMenuItems: plan.maxMenuItems,
          maxCategories: plan.maxCategories,
          maxOrdersPerMonth: plan.maxOrdersPerMonth,
          whatsappEnabled: true,
          analyticsEnabled: plan.name !== 'FREE',
          isActive: plan.isActive,
        }
      : null,
    status: subscription.status,
    startDate: subscription.startDate,
    endDate: subscription.endDate,
    trialStartDate: subscription.trialStartDate,
    trialEndDate: subscription.trialEndDate,
    trialEndsAt: subscription.trialEndDate,
    daysRemaining: usage ? usage.daysRemaining : null,
    usage: usage
      ? {
          ...usage,
          categoriesUsed: usage.categoryCount,
          menuItemsUsed: usage.menuItemCount,
        }
      : null,
    createdAt: subscription.createdAt,
    updatedAt: subscription.updatedAt,
  };
}

async function getAllSubscriptions(req, res, next) {
  try {
    const { status, search } = req.query;

    const restaurantWhere = {};
    if (search && typeof search === 'string' && search.trim()) {
      const q = search.trim();
      restaurantWhere.OR = [
        { name: { contains: q, mode: 'insensitive' } },
        { slug: { contains: q, mode: 'insensitive' } },
        { email: { contains: q, mode: 'insensitive' } },
      ];
    }

    const restaurants = await prisma.restaurant.findMany({
      where: restaurantWhere,
      orderBy: { createdAt: 'desc' },
    });

    const allEvaluated = [];
    for (const restaurant of restaurants) {
      const evaluated = await getEvaluatedSubscription(restaurant.id);
      allEvaluated.push(
        serializeEvaluatedSubscription({
          ...evaluated,
          restaurant,
        })
      );
    }

    const summary = {
      totalSubscriptions: allEvaluated.length,
      activeSubscriptions: allEvaluated.filter((s) => s.status === 'ACTIVE').length,
      trialSubscriptions: allEvaluated.filter((s) => s.status === 'TRIAL').length,
      expiredSubscriptions: allEvaluated.filter((s) => s.status === 'EXPIRED').length,
      suspendedSubscriptions: allEvaluated.filter((s) => s.status === 'SUSPENDED').length,
      cancelledSubscriptions: allEvaluated.filter((s) => s.status === 'CANCELLED').length,
    };

    const filtered =
      status && status.toUpperCase() !== 'ALL'
        ? allEvaluated.filter((s) => s.status === status.toUpperCase())
        : allEvaluated;

    res.status(200).json({
      success: true,
      message: 'Subscriptions fetched successfully',
      summary,
      data: filtered,
      subscriptions: filtered,
    });
  } catch (err) {
    next(err);
  }
}

async function getRestaurantSubscription(req, res, next) {
  try {
    const { restaurantId } = req.params;
    const restaurant = await prisma.restaurant.findUnique({ where: { id: restaurantId } });
    if (!restaurant) {
      return res.status(404).json({ success: false, message: 'Restaurant not found' });
    }

    const evaluated = await getEvaluatedSubscription(restaurantId);
    const serialized = serializeEvaluatedSubscription({
      ...evaluated,
      restaurant,
    });

    res.status(200).json({
      success: true,
      data: serialized,
      subscription: serialized,
    });
  } catch (err) {
    next(err);
  }
}

async function assignPlanToRestaurant(req, res, next) {
  try {
    const { restaurantId } = req.params;
    const { planId, status, durationDays } = req.body;

    if (!planId) {
      return res.status(400).json({ success: false, message: 'planId is required' });
    }

    const [restaurant, plan] = await Promise.all([
      prisma.restaurant.findUnique({ where: { id: restaurantId } }),
      prisma.subscriptionPlan.findUnique({ where: { id: planId } }),
    ]);

    if (!restaurant) {
      return res.status(404).json({ success: false, message: 'Restaurant not found' });
    }
    if (!plan) {
      return res.status(404).json({ success: false, message: 'Subscription plan not found' });
    }

    const targetStatus = status ? status.toUpperCase() : 'ACTIVE';
    if (!SUBSCRIPTION_STATUSES.includes(targetStatus)) {
      return res.status(400).json({
        success: false,
        message: `Status must be one of: ${SUBSCRIPTION_STATUSES.join(', ')}`,
      });
    }

    const now = new Date();
    const defaultDays = plan.billingInterval === 'YEARLY' ? 365 : 30;
    const days = durationDays !== undefined ? Number(durationDays) : defaultDays;
    const endDate = new Date(now.getTime() + days * 24 * 60 * 60 * 1000);

    await prisma.subscription.upsert({
      where: { restaurantId },
      update: {
        planId: plan.id,
        status: targetStatus,
        startDate: now,
        endDate,
      },
      create: {
        restaurantId,
        planId: plan.id,
        status: targetStatus,
        startDate: now,
        endDate,
      },
    });

    const evaluated = await getEvaluatedSubscription(restaurantId);
    const serialized = serializeEvaluatedSubscription({
      ...evaluated,
      restaurant,
    });

    res.status(200).json({
      success: true,
      message: `Plan ${plan.name} assigned to ${restaurant.name}`,
      data: serialized,
      subscription: serialized,
    });
  } catch (err) {
    next(err);
  }
}

async function updateRestaurantSubscription(req, res, next) {
  try {
    const { restaurantId } = req.params;
    const { status, extendDays, planId, startDate: customStartDate, endDate: customEndDate } = req.body;

    const restaurant = await prisma.restaurant.findUnique({ where: { id: restaurantId } });
    if (!restaurant) {
      return res.status(404).json({ success: false, message: 'Restaurant not found' });
    }

    const currentEval = await getEvaluatedSubscription(restaurantId);
    const currentSub = currentEval.subscription;

    const updateData = {};

    if (planId !== undefined) {
      const plan = await prisma.subscriptionPlan.findUnique({ where: { id: planId } });
      if (!plan) {
        return res.status(404).json({ success: false, message: 'Subscription plan not found' });
      }
      updateData.planId = plan.id;
    }

    if (status !== undefined) {
      const upperStatus = status.toUpperCase();
      if (!SUBSCRIPTION_STATUSES.includes(upperStatus)) {
        return res.status(400).json({
          success: false,
          message: `Status must be one of: ${SUBSCRIPTION_STATUSES.join(', ')}`,
        });
      }
      updateData.status = upperStatus;

      if (upperStatus === 'ACTIVE' && customEndDate === undefined) {
        const now = new Date();
        if (!currentSub.endDate || currentSub.endDate < now) {
          updateData.startDate = now;
          updateData.endDate = new Date(now.getTime() + 30 * 24 * 60 * 60 * 1000);
        }
      }
    }

    if (customStartDate !== undefined) {
      const parsedStart = new Date(customStartDate);
      if (!isNaN(parsedStart.getTime())) {
        updateData.startDate = parsedStart;
      }
    }

    if (extendDays !== undefined) {
      const days = Number(extendDays);
      if (isNaN(days) || days <= 0) {
        return res.status(400).json({ success: false, message: 'extendDays must be a positive number' });
      }
      const now = new Date();
      const baseDate = currentSub.endDate && currentSub.endDate > now ? currentSub.endDate : now;
      updateData.endDate = new Date(baseDate.getTime() + days * 24 * 60 * 60 * 1000);
      if (currentSub.status === 'EXPIRED' && !updateData.status) {
        updateData.status = 'ACTIVE';
      }
    }

    if (customEndDate !== undefined) {
      const parsed = new Date(customEndDate);
      if (isNaN(parsed.getTime())) {
        return res.status(400).json({ success: false, message: 'Invalid endDate format' });
      }
      updateData.endDate = parsed;
      if ((updateData.status || currentSub.status) === 'TRIAL') {
        updateData.trialEndDate = parsed;
      }
    }

    await prisma.subscription.update({
      where: { id: currentSub.id },
      data: updateData,
    });

    const evaluated = await getEvaluatedSubscription(restaurantId);
    const serialized = serializeEvaluatedSubscription({
      ...evaluated,
      restaurant,
    });

    res.status(200).json({
      success: true,
      message: 'Subscription updated successfully',
      data: serialized,
      subscription: serialized,
    });
  } catch (err) {
    next(err);
  }
}

module.exports = {
  getAllSubscriptions,
  getRestaurantSubscription,
  assignPlanToRestaurant,
  updateRestaurantSubscription,
  serializeEvaluatedSubscription,
};
