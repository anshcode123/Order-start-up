/**
 * Central error handler for ScanServe API.
 */
function errorHandler(err, req, res, next) {
  const timestamp = new Date().toISOString();
  console.error(`[${timestamp}] [ERROR] ${req.method} ${req.originalUrl}:`, err.message || err);

  if (err instanceof SyntaxError && err.status === 400 && 'body' in err) {
    return res.status(400).json({
      success: false,
      message: 'Invalid JSON payload received',
    });
  }

  if (err.name === 'MulterError') {
    const msg = err.code === 'LIMIT_FILE_SIZE'
      ? 'Uploaded file exceeds maximum allowed size (5MB)'
      : `File upload error: ${err.message}`;
    return res.status(400).json({
      success: false,
      message: msg,
    });
  }

  if (err.code === 'P2002') {
    return res.status(409).json({
      success: false,
      message: 'A resource with that unique identifier already exists',
    });
  }

  if (err.code === 'P2025') {
    return res.status(404).json({
      success: false,
      message: 'Resource not found',
    });
  }

  const statusCode =
    err.statusCode && err.statusCode >= 400 && err.statusCode < 600
      ? err.statusCode
      : 500;

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
