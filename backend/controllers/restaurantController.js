const validator = require('validator');
const prisma = require('../lib/prisma');
const { createRestaurantWithAdmin } = require('../services/restaurantService');
const { generateMenuQrDataUrl, buildMenuUrl } = require('../services/qrService');

const MIN_PASSWORD_LENGTH = 8;

function validateCreatePayload(body) {
  const errors = [];
  const restaurant = body.restaurant || {};
  const admin = body.admin || {};

  if (!restaurant.name || !restaurant.name.trim()) {
    errors.push('Restaurant name is required');
  }
  if (restaurant.email && !validator.isEmail(restaurant.email)) {
    errors.push('Restaurant email is invalid');
  }

  if (!admin.name || !admin.name.trim()) {
    errors.push('Admin name is required');
  }
  if (!admin.email || !validator.isEmail(admin.email)) {
    errors.push('A valid admin email is required');
  }
  if (!admin.password || admin.password.length < MIN_PASSWORD_LENGTH) {
    errors.push(`Admin password must be at least ${MIN_PASSWORD_LENGTH} characters`);
  }

  return errors;
}

// POST /api/admin/restaurants
async function createRestaurant(req, res, next) {
  try {
    const errors = validateCreatePayload(req.body);
    if (errors.length) {
      return res.status(400).json({ success: false, message: errors[0], errors });
    }

    const { restaurant: restaurantData, admin: adminData } = req.body;

    const existingAdmin = await prisma.user.findUnique({
      where: { email: adminData.email.toLowerCase() },
    });
    if (existingAdmin) {
      return res.status(409).json({ success: false, message: 'Admin email is already in use' });
    }

    const { restaurant, admin } = await createRestaurantWithAdmin({ restaurantData, adminData });

    res.status(201).json({
      success: true,
      restaurant: {
        id: restaurant.id,
        name: restaurant.name,
        slug: restaurant.slug,
        description: restaurant.description,
        phone: restaurant.phone,
        email: restaurant.email,
        address: restaurant.address,
        isActive: restaurant.isActive,
        createdAt: restaurant.createdAt,
      },
      admin: {
        id: admin.id,
        name: admin.name,
        email: admin.email,
        role: admin.role,
      },
      menuUrl: buildMenuUrl(restaurant.slug),
    });
  } catch (err) {
    // Postgres unique-violation (e.g. admin email unique constraint race,
    // or a slug collision that slipped through the generation loop).
    if (err.code === 'P2002') {
      return res.status(409).json({ success: false, message: 'That email or slug is already in use' });
    }
    next(err);
  }
}

// GET /api/admin/restaurants
async function getRestaurants(req, res, next) {
  try {
    const restaurants = await prisma.restaurant.findMany({ orderBy: { createdAt: 'desc' } });

    const restaurantIds = restaurants.map((r) => r.id);
    const admins = await prisma.user.findMany({
      where: {
        role: 'RESTAURANT_ADMIN',
        restaurantId: { in: restaurantIds },
      },
    });
    const adminByRestaurantId = new Map(admins.map((admin) => [admin.restaurantId, admin]));

    const payload = restaurants.map((restaurant) => {
      const admin = adminByRestaurantId.get(restaurant.id);
      return {
        id: restaurant.id,
        name: restaurant.name,
        slug: restaurant.slug,
        isActive: restaurant.isActive,
        createdAt: restaurant.createdAt,
        adminEmail: admin ? admin.email : null,
      };
    });

    res.status(200).json({ success: true, restaurants: payload });
  } catch (err) {
    next(err);
  }
}

// GET /api/admin/restaurants/:id
async function getRestaurantById(req, res, next) {
  try {
    const restaurant = await prisma.restaurant.findUnique({ where: { id: req.params.id } });
    if (!restaurant) {
      return res.status(404).json({ success: false, message: 'Restaurant not found' });
    }

    const admin = await prisma.user.findFirst({
      where: { role: 'RESTAURANT_ADMIN', restaurantId: restaurant.id },
    });

    res.status(200).json({
      success: true,
      restaurant: {
        id: restaurant.id,
        name: restaurant.name,
        slug: restaurant.slug,
        description: restaurant.description,
        phone: restaurant.phone,
        email: restaurant.email,
        address: restaurant.address,
        isActive: restaurant.isActive,
        createdAt: restaurant.createdAt,
        updatedAt: restaurant.updatedAt,
      },
      admin: admin ? { id: admin.id, name: admin.name, email: admin.email } : null,
      menuUrl: buildMenuUrl(restaurant.slug),
    });
  } catch (err) {
    next(err);
  }
}

// PUT /api/admin/restaurants/:id
// Slug is intentionally NOT recomputed from the name here - changing it
// would break QR codes already printed and handed out. It only changes
// if the request explicitly supplies a new `slug`.
async function updateRestaurant(req, res, next) {
  try {
    const restaurant = await prisma.restaurant.findUnique({ where: { id: req.params.id } });
    if (!restaurant) {
      return res.status(404).json({ success: false, message: 'Restaurant not found' });
    }

    const { name, description, phone, email, address, slug } = req.body;

    if (email && !validator.isEmail(email)) {
      return res.status(400).json({ success: false, message: 'Restaurant email is invalid' });
    }

    const data = {};
    if (name !== undefined) data.name = name;
    if (description !== undefined) data.description = description;
    if (phone !== undefined) data.phone = phone;
    if (email !== undefined) data.email = email;
    if (address !== undefined) data.address = address;

    if (slug !== undefined && slug !== restaurant.slug) {
      const clash = await prisma.restaurant.findUnique({ where: { slug } });
      if (clash && clash.id !== restaurant.id) {
        return res.status(409).json({ success: false, message: 'That slug is already in use' });
      }
      data.slug = slug;
    }

    const updated = await prisma.restaurant.update({ where: { id: restaurant.id }, data });

    res.status(200).json({
      success: true,
      restaurant: {
        id: updated.id,
        name: updated.name,
        slug: updated.slug,
        description: updated.description,
        phone: updated.phone,
        email: updated.email,
        address: updated.address,
        isActive: updated.isActive,
        updatedAt: updated.updatedAt,
      },
    });
  } catch (err) {
    if (err.code === 'P2002') {
      return res.status(409).json({ success: false, message: 'That slug is already in use' });
    }
    next(err);
  }
}

// PATCH /api/admin/restaurants/:id/status
async function updateRestaurantStatus(req, res, next) {
  try {
    const { status } = req.body;
    if (!['ACTIVE', 'INACTIVE'].includes(status)) {
      return res
        .status(400)
        .json({ success: false, message: 'status must be ACTIVE or INACTIVE' });
    }

    const restaurant = await prisma.restaurant.findUnique({ where: { id: req.params.id } });
    if (!restaurant) {
      return res.status(404).json({ success: false, message: 'Restaurant not found' });
    }

    const updated = await prisma.restaurant.update({
      where: { id: restaurant.id },
      data: { isActive: status === 'ACTIVE' },
    });

    res.status(200).json({
      success: true,
      restaurant: { id: updated.id, isActive: updated.isActive },
    });
  } catch (err) {
    next(err);
  }
}

// GET /api/admin/restaurants/:id/qr
async function getRestaurantQr(req, res, next) {
  try {
    const restaurant = await prisma.restaurant.findUnique({ where: { id: req.params.id } });
    if (!restaurant) {
      return res.status(404).json({ success: false, message: 'Restaurant not found' });
    }

    const { menuUrl, dataUrl } = await generateMenuQrDataUrl(restaurant.slug);

    res.status(200).json({
      success: true,
      restaurantName: restaurant.name,
      menuUrl,
      qrDataUrl: dataUrl,
    });
  } catch (err) {
    next(err);
  }
}

module.exports = {
  createRestaurant,
  getRestaurants,
  getRestaurantById,
  updateRestaurant,
  updateRestaurantStatus,
  getRestaurantQr,
};
