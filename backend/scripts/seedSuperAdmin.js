/**
 * Creates the first SUPER_ADMIN account. There is no public registration
 * (by design - see Phase 3 spec, "Do NOT add public registration"), so
 * this is the only way to get a Super Admin into the database.
 *
 * Usage:
 *   SUPER_ADMIN_NAME="Jane Doe" \
 *   SUPER_ADMIN_EMAIL="jane@scanserve.com" \
 *   SUPER_ADMIN_PASSWORD="a-strong-password" \
 *   npm run seed:super-admin
 *
 * Safe to re-run: if a user with that email already exists, it exits
 * without making changes rather than creating a duplicate.
 */
require('dotenv').config();

const bcrypt = require('bcrypt');
const prisma = require('../lib/prisma');

const BCRYPT_SALT_ROUNDS = 10;

async function run() {
  const name = process.env.SUPER_ADMIN_NAME;
  const email = process.env.SUPER_ADMIN_EMAIL;
  const password = process.env.SUPER_ADMIN_PASSWORD;

  if (!name || !email || !password) {
    console.error(
      'Set SUPER_ADMIN_NAME, SUPER_ADMIN_EMAIL, and SUPER_ADMIN_PASSWORD before running this script.'
    );
    process.exit(1);
  }

  const existing = await prisma.user.findUnique({ where: { email: email.toLowerCase() } });
  if (existing) {
    console.log(`A user with email ${email} already exists (role: ${existing.role}). Nothing to do.`);
    await prisma.$disconnect();
    return;
  }

  const hashedPassword = await bcrypt.hash(password, BCRYPT_SALT_ROUNDS);

  await prisma.user.create({
    data: {
      name,
      email: email.toLowerCase(),
      password: hashedPassword,
      role: 'SUPER_ADMIN',
      restaurantId: null,
      isActive: true,
    },
  });

  console.log(`Super Admin created: ${email}`);
  await prisma.$disconnect();
}

run().catch(async (err) => {
  console.error('Failed to seed Super Admin:', err.message);
  await prisma.$disconnect();
  process.exit(1);
});
