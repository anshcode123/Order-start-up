const { PrismaClient } = require('@prisma/client');

/**
 * Single shared PrismaClient instance for the whole app.
 * Re-requiring this file always returns the same client - don't call
 * `new PrismaClient()` anywhere else, since each instance opens its own
 * connection pool.
 */
const prisma = new PrismaClient();

module.exports = prisma;
