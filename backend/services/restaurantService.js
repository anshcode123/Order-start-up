const bcrypt = require('bcrypt');
const prisma = require('../lib/prisma');
const { slugifyBase } = require('../utils/slugify');

const BCRYPT_SALT_ROUNDS = 10;

/**
 * Generates a unique slug from a restaurant name.
 * "The Green Cafe" -> "the-green-cafe", then "-2", "-3", ... if taken.
 *
 * Accepts an optional Prisma transaction client (`tx`) so the
 * uniqueness check reads consistently within createRestaurantWithAdmin's
 * transaction. Falls back to the shared `prisma` client when called
 * standalone.
 */
async function generateUniqueSlug(name, { tx } = {}) {
  const client = tx || prisma;
  const base = slugifyBase(name) || 'restaurant';
  let candidate = base;
  let suffix = 2;

  while (await client.restaurant.findUnique({ where: { slug: candidate } })) {
    candidate = `${base}-${suffix}`;
    suffix += 1;
  }

  return candidate;
}

/**
 * Creates a Restaurant and its Restaurant Admin User together, in a
 * single Postgres transaction, so we never end up with a restaurant
 * that has no admin (or vice versa) if the second write fails.
 *
 * NOTE (migration from MongoDB): the Mongo/Mongoose version of this
 * needed a manual non-transactional fallback because transactions
 * require a MongoDB replica set. Postgres supports transactions on a
 * single standalone instance, so that fallback is gone - this is
 * simpler than the Phase 3 original.
 */
async function createRestaurantWithAdmin({ restaurantData, adminData }) {
  return prisma.$transaction(async (tx) => {
    const slug = await generateUniqueSlug(restaurantData.name, { tx });

    const restaurant = await tx.restaurant.create({
      data: {
        name: restaurantData.name,
        slug,
        description: restaurantData.description || '',
        phone: restaurantData.phone || '',
        email: restaurantData.email || '',
        address: restaurantData.address || '',
        whatsappNumber: restaurantData.whatsappNumber || '',
        isActive: true,
      },
    });

    const hashedPassword = await bcrypt.hash(adminData.password, BCRYPT_SALT_ROUNDS);

    const admin = await tx.user.create({
      data: {
        name: adminData.name,
        email: adminData.email.toLowerCase(),
        password: hashedPassword,
        role: 'RESTAURANT_ADMIN',
        restaurantId: restaurant.id,
        isActive: true,
      },
    });

    return { restaurant, admin };
  });
}

module.exports = { generateUniqueSlug, createRestaurantWithAdmin };
