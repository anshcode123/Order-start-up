require('dotenv').config();

const express = require('express');
const cors = require('cors');

const connectDB = require('./config/db');
const healthRoutes = require('./routes/health');
const authRoutes = require('./routes/authRoutes');
const notFound = require('./middleware/notFound');
const errorHandler = require('./middleware/errorHandler');

const PORT = process.env.PORT || 5000;

function createApp() {
  const app = express();

  // Security / parsing basics
  app.use(cors({ origin: process.env.CLIENT_ORIGIN || '*' }));
  app.use(express.json({ limit: '1mb' }));
  app.use(express.urlencoded({ extended: true, limit: '1mb' }));

  // Routes
  app.use('/api/health', healthRoutes);
  app.use('/api/auth', authRoutes);

  // 404 + error handling (must be last)
  app.use(notFound);
  app.use(errorHandler);

  return app;
}

async function start() {
  try {
    // Connect to MongoDB BEFORE starting the HTTP server.
    await connectDB();

    const app = createApp();

    app.listen(PORT, () => {
      console.log(`ScanServe API listening on port ${PORT}`);
    });
  } catch (err) {
    console.error('Failed to start ScanServe API:', err.message);
    process.exit(1);
  }
}

start();
