/**
 * In-memory sliding-window rate limiter for Express (Phase 12).
 */
function createRateLimiter({
  windowMs = 60 * 1000,
  max = 60,
  message = 'Too many requests. Please try again later.',
}) {
  const requests = new Map();

  const cleanupTimer = setInterval(() => {
    const now = Date.now();
    for (const [key, timestamps] of requests.entries()) {
      const valid = timestamps.filter((t) => now - t < windowMs);
      if (valid.length === 0) {
        requests.delete(key);
      } else {
        requests.set(key, valid);
      }
    }
  }, 120000);
  if (cleanupTimer.unref) cleanupTimer.unref();

  return function rateLimiter(req, res, next) {
    if (
      process.env.NODE_ENV === 'test' ||
      process.env.DISABLE_RATE_LIMIT === 'true'
    ) {
      return next();
    }

    const ip =
      req.headers['x-forwarded-for']?.split(',')[0].trim() ||
      req.ip ||
      req.socket?.remoteAddress ||
      'unknown-ip';
    const now = Date.now();

    const clientTimestamps = requests.get(ip) || [];
    const recent = clientTimestamps.filter((t) => now - t < windowMs);

    if (recent.length >= max) {
      res.setHeader('Retry-After', Math.ceil((windowMs - (now - recent[0])) / 1000));
      return res.status(429).json({
        success: false,
        message,
      });
    }

    recent.push(now);
    requests.set(ip, recent);

    res.setHeader('X-RateLimit-Limit', max);
    res.setHeader('X-RateLimit-Remaining', Math.max(0, max - recent.length));

    next();
  };
}

const authRateLimiter = createRateLimiter({
  windowMs: 60 * 1000,
  max: 15,
  message: 'Too many login attempts. Please wait a minute and try again.',
});

const orderRateLimiter = createRateLimiter({
  windowMs: 60 * 1000,
  max: 40,
  message: 'Too many order submissions. Please wait a moment and try again.',
});

const globalRateLimiter = createRateLimiter({
  windowMs: 60 * 1000,
  max: 300,
  message: 'Too many requests from this IP. Please slow down.',
});

module.exports = {
  createRateLimiter,
  authRateLimiter,
  orderRateLimiter,
  globalRateLimiter,
};
