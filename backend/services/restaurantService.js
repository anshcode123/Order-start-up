const bcrypt = require('bcrypt');
const prisma = require('../lib/prisma');
const { slugifyBase } = require('../utils/slugify');
const { createTrialSubscription } = require('./subscriptionService');

const BCRYPT_SALT_ROUNDS = 10;

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

    const subscription = await createTrialSubscription(restaurant.id, tx);

    return { restaurant, admin, subscription };
  });
}

module.exports = { generateUniqueSlug, createRestaurantWithAdmin };
