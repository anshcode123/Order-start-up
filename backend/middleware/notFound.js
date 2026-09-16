/**
 * Catches any request that didn't match a route above it.
 * Register this AFTER all routes and BEFORE the error handler.
 */
function notFound(req, res, next) {
  res.status(404).json({
    success: false,
    message: 'Route not found',
  });
}

module.exports = notFound;
