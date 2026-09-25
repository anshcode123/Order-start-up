const express = require('express');

const router = express.Router();

// GET /api/health
router.get('/', (req, res) => {
  res.status(200).json({
    success: true,
    status: 'ok',
    service: 'scanserve-backend',
    timestamp: new Date().toISOString(),
    message: 'ScanServe API is running',
  });
});

module.exports = router;
