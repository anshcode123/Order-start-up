const express = require('express');
const { getPublicMenu } = require('../controllers/publicMenuController');

const router = express.Router();

// Intentionally no protect()/authorize() here - this is the public,
// unauthenticated customer-facing menu (Phase 5). restaurantId is never
// accepted from the client; the controller derives it from the slug.
router.get('/:restaurantSlug', getPublicMenu);

module.exports = router;
