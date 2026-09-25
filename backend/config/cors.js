/**
 * Dynamic CORS configuration for Express and Socket.IO (Phase 12)
 */
const LOCALHOST_REGEX = /^https?:\/\/(localhost|127\.0\.0\.1)(:\d+)?$/;

function buildCorsOriginValidator() {
  const rawOrigins = process.env.CLIENT_ORIGIN || '';
  const allowedList = rawOrigins
    .split(',')
    .map((o) => o.trim())
    .filter(Boolean);

  const isProd = process.env.NODE_ENV === 'production';

  return function (origin, callback) {
    // Allow non-browser / server-to-server / mobile native requests
    if (!origin) return callback(null, true);

    if (allowedList.includes(origin)) return callback(null, true);

    // In development, allow any localhost port (e.g. Flutter web random dev port)
    if (!isProd && LOCALHOST_REGEX.test(origin)) {
      return callback(null, true);
    }

    return callback(new Error('Origin not allowed by CORS'));
  };
}

const corsOptions = {
  origin: buildCorsOriginValidator(),
  credentials: true,
};

module.exports = {
  corsOptions,
  buildCorsOriginValidator,
};
