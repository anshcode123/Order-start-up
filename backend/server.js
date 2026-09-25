require('dotenv').config();

const http = require('http');
const express = require('express');
const cors = require('cors');

const connectDB = require('./config/db');
const prisma = require('./lib/prisma');
const { initializeSocket } = require('./lib/socket');
const healthRoutes = require('./routes/health');
const authRoutes = require('./routes/auth');
const adminRoutes = require('./routes/admin');
const restaurantRoutes = require('./routes/restaurants');
const categoryRoutes = require('./routes/categories');
const menuItemRoutes = require('./routes/menuItems');
const restaurantSelfRoutes = require('./routes/restaurantSelf');
const publicMenuRoutes = require('./routes/publicMenu');
const publicOrderRoutes = require('./routes/publicOrders');

const orderRoutes = require('./routes/orders');
const superAdminRoutes = require('./routes/superAdmin');
const { corsOptions } = require('./config/cors');
const securityHeaders = require('./middleware/security');
const { globalRateLimiter } = require('./middleware/rateLimiter');
const notFound = require('./middleware/notFound');
const errorHandler = require('./middleware/errorHandler');

const PORT = process.env.PORT || 5000;

function createApp() {
  const app = express();

  app.disable('x-powered-by');
  app.use(securityHeaders);
  app.use(cors(corsOptions));

  app.use(express.json({ limit: '1mb' }));
  app.use(express.urlencoded({ extended: true, limit: '1mb' }));

  app.use(globalRateLimiter);

  app.use('/api/health', healthRoutes);
  app.use('/api/auth', authRoutes);
  app.use('/api/admin', adminRoutes);
  app.use('/api/super-admin', superAdminRoutes);
  app.use('/api/restaurants', restaurantRoutes);

  app.use('/api/restaurant/categories', categoryRoutes);
  app.use('/api/categories', categoryRoutes);
  app.use('/api/restaurant/menu-items', menuItemRoutes);
  app.use('/api/menu', menuItemRoutes);
  app.use('/api/restaurant/orders', orderRoutes);
  app.use('/api/restaurant', restaurantSelfRoutes);
  app.use('/api/public/menu', publicMenuRoutes);
  app.use('/api/public/orders', publicOrderRoutes);

  app.use(notFound);
  app.use(errorHandler);

  return app;
}

async function start() {
  try {
    await connectDB();

    const { seedDefaultPlans } = require('./services/subscriptionService');
    await seedDefaultPlans();

    const app = createApp();
    const server = http.createServer(app);
    initializeSocket(server);

    server.listen(PORT, () => {
      console.log(`ScanServe API (HTTP + Socket.IO) listening on port ${PORT}`);
    });
  } catch (err) {
    console.error('Failed to start ScanServe API:', err.message);
    process.exit(1);
  }
}

async function shutdown() {
  await prisma.$disconnect();
  process.exit(0);
}

process.on('SIGINT', shutdown);
process.on('SIGTERM', shutdown);

start();
