const jwt = require('jsonwebtoken');

const JWT_EXPIRES_IN = process.env.JWT_EXPIRES_IN || '7d';

/**
 * Signs a JWT carrying the minimum needed for authorization decisions.
 * Keep the payload small and stable - controllers/middleware rely on
 * exactly these three fields being present on req.user after verifyToken.
 */
function signToken({ id, role, restaurant }) {
  if (!process.env.JWT_SECRET) {
    throw new Error('JWT_SECRET is not set in the environment');
  }

  return jwt.sign({ id, role, restaurant: restaurant || null }, process.env.JWT_SECRET, {
    expiresIn: JWT_EXPIRES_IN,
  });
}

function verifyToken(token) {
  if (!process.env.JWT_SECRET) {
    throw new Error('JWT_SECRET is not set in the environment');
  }
  return jwt.verify(token, process.env.JWT_SECRET);
}

module.exports = { signToken, verifyToken };
