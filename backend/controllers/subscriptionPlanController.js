const { Prisma } = require('@prisma/client');
const prisma = require('../lib/prisma');
const { BILLING_INTERVALS } = require('../config/subscription');

function serializePlan(plan) {
  const priceStr = plan.price.toString();
  return {
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
    subscriptionCount: plan._count ? plan._count.subscriptions : undefined,
    createdAt: plan.createdAt,
    updatedAt: plan.updatedAt,
  };
}

async function getPlans(req, res, next) {
  try {
    const plans = await prisma.subscriptionPlan.findMany({
      orderBy: { price: 'asc' },
      include: {
        _count: { select: { subscriptions: true } },
      },
    });
    const serialized = plans.map(serializePlan);

    res.status(200).json({
      success: true,
      message: 'Subscription plans fetched successfully',
      data: serialized,
      plans: serialized,
    });
  } catch (err) {
    next(err);
  }
}

async function getPlanById(req, res, next) {
  try {
    const plan = await prisma.subscriptionPlan.findUnique({
      where: { id: req.params.id },
      include: {
        _count: { select: { subscriptions: true } },
      },
    });

    if (!plan) {
      return res.status(404).json({ success: false, message: 'Plan not found' });
    }

    const serialized = serializePlan(plan);
    res.status(200).json({
      success: true,
      data: serialized,
      plan: serialized,
    });
  } catch (err) {
    next(err);
  }
}

async function createPlan(req, res, next) {
  try {
    const {
      name,
      description,
      price,
      priceMonthly,
      billingInterval,
      maxMenuItems,
      maxCategories,
      maxOrdersPerMonth,
      isActive,
    } = req.body;

    if (!name || !name.trim()) {
      return res.status(400).json({ success: false, message: 'Plan name is required' });
    }

    const rawPrice = price !== undefined ? price : priceMonthly;
    if (rawPrice === undefined || rawPrice === null || isNaN(Number(rawPrice)) || Number(rawPrice) < 0) {
      return res.status(400).json({ success: false, message: 'Valid non-negative price is required' });
    }

    const interval = billingInterval ? billingInterval.toUpperCase() : 'MONTHLY';
    if (!BILLING_INTERVALS.includes(interval)) {
      return res.status(400).json({
        success: false,
        message: `Billing interval must be one of: ${BILLING_INTERVALS.join(', ')}`,
      });
    }

    const existing = await prisma.subscriptionPlan.findUnique({
      where: { name: name.trim().toUpperCase() },
    });
    if (existing) {
      return res.status(409).json({ success: false, message: 'A plan with this name already exists' });
    }

    const plan = await prisma.subscriptionPlan.create({
      data: {
        name: name.trim().toUpperCase(),
        description: description ? description.trim() : '',
        price: new Prisma.Decimal(String(rawPrice)),
        billingInterval: interval,
        maxMenuItems: maxMenuItems !== undefined && maxMenuItems !== null ? Number(maxMenuItems) : null,
        maxCategories: maxCategories !== undefined && maxCategories !== null ? Number(maxCategories) : null,
        maxOrdersPerMonth: maxOrdersPerMonth !== undefined && maxOrdersPerMonth !== null ? Number(maxOrdersPerMonth) : null,
        isActive: isActive !== undefined ? Boolean(isActive) : true,
      },
    });

    const serialized = serializePlan(plan);
    res.status(201).json({
      success: true,
      message: 'Subscription plan created successfully',
      data: serialized,
      plan: serialized,
    });
  } catch (err) {
    next(err);
  }
}

async function updatePlan(req, res, next) {
  try {
    const existing = await prisma.subscriptionPlan.findUnique({
      where: { id: req.params.id },
    });
    if (!existing) {
      return res.status(404).json({ success: false, message: 'Plan not found' });
    }

    const {
      name,
      description,
      price,
      priceMonthly,
      billingInterval,
      maxMenuItems,
      maxCategories,
      maxOrdersPerMonth,
      isActive,
    } = req.body;

    const updateData = {};
    if (name !== undefined) {
      if (!name.trim()) {
        return res.status(400).json({ success: false, message: 'Plan name cannot be empty' });
      }
      updateData.name = name.trim().toUpperCase();
    }

    if (description !== undefined) {
      updateData.description = description.trim();
    }

    const rawPrice = price !== undefined ? price : priceMonthly;
    if (rawPrice !== undefined) {
      if (isNaN(Number(rawPrice)) || Number(rawPrice) < 0) {
        return res.status(400).json({ success: false, message: 'Valid non-negative price is required' });
      }
      updateData.price = new Prisma.Decimal(String(rawPrice));
    }

    if (billingInterval !== undefined) {
      const interval = billingInterval.toUpperCase();
      if (!BILLING_INTERVALS.includes(interval)) {
        return res.status(400).json({
          success: false,
          message: `Billing interval must be one of: ${BILLING_INTERVALS.join(', ')}`,
        });
      }
      updateData.billingInterval = interval;
    }

    if (maxMenuItems !== undefined) {
      updateData.maxMenuItems = maxMenuItems !== null ? Number(maxMenuItems) : null;
    }
    if (maxCategories !== undefined) {
      updateData.maxCategories = maxCategories !== null ? Number(maxCategories) : null;
    }
    if (maxOrdersPerMonth !== undefined) {
      updateData.maxOrdersPerMonth = maxOrdersPerMonth !== null ? Number(maxOrdersPerMonth) : null;
    }
    if (isActive !== undefined) {
      updateData.isActive = Boolean(isActive);
    }

    const updated = await prisma.subscriptionPlan.update({
      where: { id: req.params.id },
      data: updateData,
    });

    const serialized = serializePlan(updated);
    res.status(200).json({
      success: true,
      message: 'Subscription plan updated successfully',
      data: serialized,
      plan: serialized,
    });
  } catch (err) {
    if (err.code === 'P2002') {
      return res.status(409).json({ success: false, message: 'A plan with this name already exists' });
    }
    next(err);
  }
}

async function updatePlanStatus(req, res, next) {
  try {
    const { isActive } = req.body;
    if (isActive === undefined) {
      return res.status(400).json({ success: false, message: 'isActive boolean is required' });
    }

    const existing = await prisma.subscriptionPlan.findUnique({
      where: { id: req.params.id },
    });
    if (!existing) {
      return res.status(404).json({ success: false, message: 'Plan not found' });
    }

    const updated = await prisma.subscriptionPlan.update({
      where: { id: req.params.id },
      data: { isActive: Boolean(isActive) },
    });

    const serialized = serializePlan(updated);
    res.status(200).json({
      success: true,
      message: `Plan ${updated.isActive ? 'activated' : 'deactivated'} successfully`,
      data: serialized,
      plan: serialized,
    });
  } catch (err) {
    next(err);
  }
}

async function deletePlan(req, res, next) {
  try {
    const plan = await prisma.subscriptionPlan.findUnique({
      where: { id: req.params.id },
      include: {
        _count: { select: { subscriptions: true } },
      },
    });

    if (!plan) {
      return res.status(404).json({ success: false, message: 'Plan not found' });
    }

    if (plan._count.subscriptions > 0) {
      return res.status(409).json({
        success: false,
        message: 'Cannot delete a plan currently assigned to restaurants. Deactivate the plan instead.',
      });
    }

    await prisma.subscriptionPlan.delete({
      where: { id: req.params.id },
    });

    res.status(200).json({
      success: true,
      message: 'Subscription plan deleted successfully',
    });
  } catch (err) {
    next(err);
  }
}

module.exports = {
  getPlans,
  getPlanById,
  createPlan,
  updatePlan,
  updatePlanStatus,
  deletePlan,
};
