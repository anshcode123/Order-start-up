const prisma = require('../lib/prisma');

/**
 * Verifies the PostgreSQL connection (via Prisma) is reachable, so
 * server.js can keep its existing "don't start Express until the DB is
 * up" behavior from Phase 3 - only the underlying check changed
 * (Postgres/Prisma instead of MongoDB/Mongoose).
 */
async function connectDB() {
  await prisma.$connect();
  console.log('Connected to PostgreSQL via Prisma');
  return prisma;
}

module.exports = connectDB;
