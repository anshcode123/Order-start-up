const express = require('express');
const {
  getPlatformStats,
  getOrderAnalytics,
  getRestaurantStats,
} = require('../controllers/superAdminAnalyticsController');
const {
  getPlans,
  getPlanById,
  createPlan,
  updatePlan,
  updatePlanStatus,
  deletePlan,
} = require('../controllers/subscriptionPlanController');
const {
  getAllSubscriptions,
  getRestaurantSubscription,
  assignPlanToRestaurant,
  updateRestaurantSubscription,
} = require('../controllers/superAdminSubscriptionController');
const { protect, authorize } = require('../middleware/auth');

const router = express.Router();

router.use(protect, authorize('SUPER_ADMIN'));

router.get('/dashboard/stats', getPlatformStats);
router.get('/analytics/orders', getOrderAnalytics);
router.get('/restaurants/:id/stats', getRestaurantStats);

router.get('/plans', getPlans);
router.get('/plans/:id', getPlanById);
router.post('/plans', createPlan);
router.put('/plans/:id', updatePlan);
router.patch('/plans/:id/status', updatePlanStatus);
router.delete('/plans/:id', deletePlan);

router.get('/subscriptions', getAllSubscriptions);
router.get('/subscriptions/:restaurantId', getRestaurantSubscription);
router.post('/subscriptions/:restaurantId', assignPlanToRestaurant);
router.put('/subscriptions/:restaurantId', assignPlanToRestaurant);
router.patch('/subscriptions/:restaurantId', updateRestaurantSubscription);

router.get('/restaurants/:restaurantId/subscription', getRestaurantSubscription);
router.post('/restaurants/:restaurantId/subscription', assignPlanToRestaurant);
router.put('/restaurants/:restaurantId/subscription', assignPlanToRestaurant);
router.patch('/restaurants/:restaurantId/subscription', updateRestaurantSubscription);

module.exports = router;
