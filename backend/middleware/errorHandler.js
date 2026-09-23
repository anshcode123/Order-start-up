/**
 * Central error handler.
 * Any error passed to next(err) anywhere in the app ends up here.
 * Keep this as the LAST piece of middleware registered in server.js.
 */
function errorHandler(err, req, res, next) {
  console.error(err.stack || err.message || err);

  const statusCode = err.statusCode && err.statusCode >= 400 && err.statusCode < 600 ? err.statusCode : 500;

  const isProd = process.env.NODE_ENV === 'production';
  let message = err.message || 'Internal server error';
  if (statusCode === 500 && isProd) {
    message = 'An unexpected server error occurred. Please try again later.';
  }

  res.status(statusCode).json({
    success: false,
    message,
  });
}


module.exports = errorHandler;
