const prisma = require('../lib/prisma');
const { getEvaluatedSubscription } = require('../services/subscriptionService');
const { serializeEvaluatedSubscription } = require('./superAdminSubscriptionController');

async function getOwnSubscription(req, res, next) {
  try {
    const restaurantId = req.user.restaurantId;
    if (!restaurantId) {
      return res.status(400).json({
        success: false,
        message: 'No restaurant associated with this account',
      });
    }

    const restaurant = await prisma.restaurant.findUnique({
      where: { id: restaurantId },
    });
    if (!restaurant) {
      return res.status(404).json({
        success: false,
        message: 'Restaurant not found',
      });
    }

    const evaluated = await getEvaluatedSubscription(restaurantId);
    const serialized = serializeEvaluatedSubscription({
      ...evaluated,
      restaurant,
    });

    res.status(200).json({
      success: true,
      message: 'Subscription fetched successfully',
      data: serialized,
      subscription: serialized,
    });
  } catch (err) {
    next(err);
  }
}

module.exports = {
  getOwnSubscription,
};
