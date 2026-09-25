const prisma = require('../lib/prisma');
const { uploadMenuItemImage } = require('../services/cloudinaryService');
const { assertActiveSubscription, checkMenuItemLimit } = require('../services/subscriptionService');

function serializeMenuItem(item) {
  return {
    id: item.id,
    name: item.name,
    description: item.description,
    price: item.price.toString(),
    imageUrl: item.imageUrl,
    isAvailable: item.isAvailable,
    categoryId: item.categoryId,
    categoryName: item.category ? item.category.name : undefined,
    createdAt: item.createdAt,
    updatedAt: item.updatedAt,
  };
}

function validatePrice(price) {
  if (price === undefined || price === null || price === '') return 'Price is required';
  const numeric = Number(price);
  if (Number.isNaN(numeric)) return 'Price must be a number';
  if (numeric < 0) return 'Price must be 0 or greater';
  return null;
}

async function categoryBelongsToRestaurant(categoryId, restaurantId) {
  const category = await prisma.category.findUnique({ where: { id: categoryId } });
  return !!category && category.restaurantId === restaurantId;
}

async function getMenuItems(req, res, next) {
  try {
    const { categoryId, isAvailable, search } = req.query;

    const where = { restaurantId: req.user.restaurantId };
    if (categoryId) where.categoryId = categoryId;
    if (isAvailable === 'true') where.isAvailable = true;
    if (isAvailable === 'false') where.isAvailable = false;
    if (search) where.name = { contains: search, mode: 'insensitive' };

    const items = await prisma.menuItem.findMany({
      where,
      include: { category: { select: { name: true } } },
      orderBy: { name: 'asc' },
    });

    res.status(200).json({
      success: true,
      message: 'Menu items fetched successfully',
      data: items.map(serializeMenuItem),
    });
  } catch (err) {
    next(err);
  }
}

async function getMenuItemById(req, res, next) {
  try {
    const item = await prisma.menuItem.findUnique({
      where: { id: req.params.id },
      include: { category: { select: { name: true } } },
    });

    if (!item || item.restaurantId !== req.user.restaurantId) {
      return res.status(404).json({ success: false, message: 'Menu item not found' });
    }

    res.status(200).json({
      success: true,
      message: 'Menu item fetched successfully',
      data: serializeMenuItem(item),
    });
  } catch (err) {
    next(err);
  }
}

async function createMenuItem(req, res, next) {
  try {
    await assertActiveSubscription(req.user.restaurantId);
    await checkMenuItemLimit(req.user.restaurantId);

    const { name, description, price, categoryId, imageUrl, isAvailable } = req.body;

    if (!name || !name.trim()) {
      return res.status(400).json({ success: false, message: 'Food name is required' });
    }
    if (!categoryId) {
      return res.status(400).json({ success: false, message: 'Category is required' });
    }
    const priceError = validatePrice(price);
    if (priceError) {
      return res.status(400).json({ success: false, message: priceError });
    }

    const categoryOk = await categoryBelongsToRestaurant(categoryId, req.user.restaurantId);
    if (!categoryOk) {
      return res.status(404).json({
        success: false,
        message: 'Selected category does not belong to your restaurant',
      });
    }

    const item = await prisma.menuItem.create({
      data: {
        restaurantId: req.user.restaurantId,
        categoryId,
        name: name.trim(),
        description: description ? description.trim() : '',
        price: String(price),
        imageUrl: imageUrl || null,
        isAvailable: isAvailable === undefined ? true : Boolean(isAvailable),
      },
      include: { category: { select: { name: true } } },
    });

    const serialized = serializeMenuItem(item);
    res.status(201).json({
      success: true,
      message: 'Menu item created successfully',
      data: serialized,
      menuItem: serialized,
    });
  } catch (err) {
    next(err);
  }
}

async function updateMenuItem(req, res, next) {
  try {
    const existing = await prisma.menuItem.findUnique({ where: { id: req.params.id } });
    if (!existing || existing.restaurantId !== req.user.restaurantId) {
      return res.status(404).json({ success: false, message: 'Menu item not found' });
    }

    const { name, description, price, categoryId, imageUrl, isAvailable } = req.body;

    if (name !== undefined && !name.trim()) {
      return res.status(400).json({ success: false, message: 'Food name cannot be empty' });
    }
    if (price !== undefined) {
      const priceError = validatePrice(price);
      if (priceError) return res.status(400).json({ success: false, message: priceError });
    }
    if (categoryId !== undefined) {
      const categoryOk = await categoryBelongsToRestaurant(categoryId, req.user.restaurantId);
      if (!categoryOk) {
        return res.status(400).json({
          success: false,
          message: 'Selected category does not belong to your restaurant',
        });
      }
    }

    const data = {};
    if (name !== undefined) data.name = name.trim();
    if (description !== undefined) data.description = description.trim();
    if (price !== undefined) data.price = String(price);
    if (categoryId !== undefined) data.categoryId = categoryId;
    if (imageUrl !== undefined) data.imageUrl = imageUrl || null;
    if (isAvailable !== undefined) data.isAvailable = Boolean(isAvailable);

    const updated = await prisma.menuItem.update({
      where: { id: existing.id },
      data,
      include: { category: { select: { name: true } } },
    });

    res.status(200).json({
      success: true,
      message: 'Menu item updated successfully',
      data: serializeMenuItem(updated),
    });
  } catch (err) {
    next(err);
  }
}

async function toggleMenuItemAvailability(req, res, next) {
  try {
    const existing = await prisma.menuItem.findUnique({ where: { id: req.params.id } });
    if (!existing || existing.restaurantId !== req.user.restaurantId) {
      return res.status(404).json({ success: false, message: 'Menu item not found' });
    }

    const nextValue =
      req.body.isAvailable !== undefined ? Boolean(req.body.isAvailable) : !existing.isAvailable;

    const updated = await prisma.menuItem.update({
      where: { id: existing.id },
      data: { isAvailable: nextValue },
      include: { category: { select: { name: true } } },
    });

    res.status(200).json({
      success: true,
      message: `Menu item marked as ${updated.isAvailable ? 'available' : 'unavailable'}`,
      data: serializeMenuItem(updated),
    });
  } catch (err) {
    next(err);
  }
}

async function deleteMenuItem(req, res, next) {
  try {
    const existing = await prisma.menuItem.findUnique({ where: { id: req.params.id } });
    if (!existing || existing.restaurantId !== req.user.restaurantId) {
      return res.status(404).json({ success: false, message: 'Menu item not found' });
    }

    await prisma.menuItem.delete({ where: { id: existing.id } });

    res.status(200).json({
      success: true,
      message: 'Menu item deleted successfully',
    });
  } catch (err) {
    next(err);
  }
}

async function uploadImage(req, res, next) {
  try {
    if (!req.file) {
      return res.status(400).json({ success: false, message: 'No image file provided' });
    }

    const { imageUrl } = await uploadMenuItemImage(req.file.buffer, {
      restaurantId: req.user.restaurantId,
    });

    res.status(200).json({
      success: true,
      message: 'Image uploaded successfully',
      data: { imageUrl },
    });
  } catch (err) {
    next(err);
  }
}

module.exports = {
  getMenuItems,
  getMenuItemById,
  createMenuItem,
  updateMenuItem,
  toggleMenuItemAvailability,
  updateAvailability: toggleMenuItemAvailability,
  deleteMenuItem,
  uploadImage,
};
