const prisma = require('../lib/prisma');
const { generateMenuQrDataUrl } = require('../services/qrService');

// GET /api/restaurant/dashboard
// Real counts for the authenticated Restaurant Admin's own restaurant
// only - Phase 4 spec #19 ("Do not show fake statistics").
async function getRestaurantAdminDashboard(req, res, next) {
  try {
    const restaurantId = req.user.restaurantId;

    const [totalCategories, totalMenuItems, availableItems] = await Promise.all([
      prisma.category.count({ where: { restaurantId } }),
      prisma.menuItem.count({ where: { restaurantId } }),
      prisma.menuItem.count({ where: { restaurantId, isAvailable: true } }),
    ]);

    res.status(200).json({
      success: true,
      message: 'Dashboard stats fetched successfully',
      data: {
        totalCategories,
        totalMenuItems,
        availableItems,
        unavailableItems: totalMenuItems - availableItems,
      },
    });
  } catch (err) {
    next(err);
  }
}

// GET /api/restaurant/qr
// Same QR image the Super Admin sees at
// GET /api/admin/restaurants/:id/qr, but self-service: the restaurant
// is always the caller's own (req.user.restaurantId), never a param.
async function getOwnRestaurantQr(req, res, next) {
  try {
    const restaurant = await prisma.restaurant.findUnique({
      where: { id: req.user.restaurantId },
    });
    if (!restaurant) {
      return res.status(404).json({ success: false, message: 'Restaurant not found' });
    }

    const { menuUrl, dataUrl } = await generateMenuQrDataUrl(restaurant.slug);

    res.status(200).json({
      success: true,
      message: 'QR code generated successfully',
      data: { restaurantName: restaurant.name, menuUrl, qrDataUrl: dataUrl },
    });
  } catch (err) {
    next(err);
  }
}

// GET /api/restaurant/settings
// Fetches the authenticated restaurant admin's restaurant settings.
// Strictly scoped to req.user.restaurantId.
async function getRestaurantSettings(req, res, next) {
  try {
    const restaurant = await prisma.restaurant.findUnique({
      where: { id: req.user.restaurantId },
    });
    if (!restaurant) {
      return res.status(404).json({ success: false, message: 'Restaurant not found' });
    }

    res.status(200).json({
      success: true,
      message: 'Settings fetched successfully',
      data: {
        id: restaurant.id,
        name: restaurant.name,
        slug: restaurant.slug,
        phone: restaurant.phone,
        email: restaurant.email,
        address: restaurant.address,
        description: restaurant.description,
        whatsappNumber: restaurant.whatsappNumber,
        logoUrl: restaurant.logoUrl,
        isActive: restaurant.isActive,
      },
    });
  } catch (err) {
    next(err);
  }
}

// PUT /api/restaurant/settings
// Updates settings for the authenticated restaurant admin's restaurant.
// Strictly scoped to req.user.restaurantId - never trusts a restaurantId from body or params.
async function updateRestaurantSettings(req, res, next) {
  try {
    const restaurant = await prisma.restaurant.findUnique({
      where: { id: req.user.restaurantId },
    });
    if (!restaurant) {
      return res.status(404).json({ success: false, message: 'Restaurant not found' });
    }

    const {
      name,
      description,
      phone,
      whatsappNumber,
      email,
      address,
      logoUrl,
      isActive,
    } = req.body;

    const data = {};

    if (name !== undefined) {
      const trimmedName = typeof name === 'string' ? name.trim() : '';
      if (!trimmedName) {
        return res.status(400).json({ success: false, message: 'Restaurant name cannot be empty' });
      }
      data.name = trimmedName;
    }

    if (description !== undefined) {
      data.description = typeof description === 'string' ? description.trim() : '';
    }

    if (phone !== undefined) {
      data.phone = typeof phone === 'string' ? phone.trim() : '';
    }

    if (address !== undefined) {
      data.address = typeof address === 'string' ? address.trim() : '';
    }

    if (email !== undefined) {
      const trimmedEmail = typeof email === 'string' ? email.trim() : '';
      if (trimmedEmail && !trimmedEmail.includes('@')) {
        return res.status(400).json({ success: false, message: 'Please enter a valid email address' });
      }
      data.email = trimmedEmail;
    }

    if (whatsappNumber !== undefined) {
      const trimmed = typeof whatsappNumber === 'string' ? whatsappNumber.trim() : '';
      if (trimmed) {
        // Validate digits length (E.164 permits 7 to 15 digits)
        const digits = trimmed.replace(/\D/g, '');
        if (digits.length < 7 || digits.length > 15) {
          return res.status(400).json({
            success: false,
            message: 'Please enter a valid WhatsApp phone number with country code (e.g. +91XXXXXXXXXX)',
          });
        }
      }
      data.whatsappNumber = trimmed;
    }

    if (logoUrl !== undefined) {
      data.logoUrl = typeof logoUrl === 'string' ? logoUrl.trim() : null;
    }

    if (isActive !== undefined) {
      data.isActive = Boolean(isActive);
    }

    const updated = await prisma.restaurant.update({
      where: { id: restaurant.id },
      data,
    });

    res.status(200).json({
      success: true,
      message: 'Settings updated successfully',
      data: {
        id: updated.id,
        name: updated.name,
        slug: updated.slug,
        phone: updated.phone,
        email: updated.email,
        address: updated.address,
        description: updated.description,
        whatsappNumber: updated.whatsappNumber,
        logoUrl: updated.logoUrl,
        isActive: updated.isActive,
      },
    });
  } catch (err) {
    next(err);
  }
}

// POST /api/restaurant/settings/logo
// Uploads restaurant logo to Cloudinary and saves URL to the restaurant record.
async function uploadLogo(req, res, next) {
  try {
    if (!req.file) {
      return res.status(400).json({ success: false, message: 'No logo image file was provided' });
    }

    const { uploadRestaurantLogo } = require('../services/cloudinaryService');
    const url = await uploadRestaurantLogo(req.file.buffer, req.file.mimetype);

    const updated = await prisma.restaurant.update({
      where: { id: req.user.restaurantId },
      data: { logoUrl: url },
    });

    res.status(200).json({
      success: true,
      message: 'Logo uploaded successfully',
      data: { logoUrl: updated.logoUrl },
    });
  } catch (err) {
    next(err);
  }
}

module.exports = {
  getRestaurantAdminDashboard,
  getOwnRestaurantQr,
  getRestaurantSettings,
  updateRestaurantSettings,
  uploadLogo,
};
