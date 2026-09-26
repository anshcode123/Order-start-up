const prisma = require('../lib/prisma');
const { uploadMenuItemImage } = require('../services/cloudinaryService');
const { assertActiveSubscription, checkMenuItemLimit } = require('../services/subscriptionService');

const ALLOWED_VARIANT_NAMES = {
  half: { name: 'Half', sortOrder: 0 },
  full: { name: 'Full', sortOrder: 1 },
};

function serializeVariant(variant) {
  return {
    id: variant.id,
    menuItemId: variant.menuItemId,
    name: variant.name,
    price: variant.price.toString(),
    sortOrder: variant.sortOrder,
    isAvailable: variant.isAvailable,
    createdAt: variant.createdAt,
    updatedAt: variant.updatedAt,
  };
}

function serializeMenuItem(item) {
  const variants = Array.isArray(item.variants)
    ? [...item.variants].sort((a, b) => a.sortOrder - b.sortOrder).map(serializeVariant)
    : [];

  return {
    id: item.id,
    name: item.name,
    description: item.description,
    price: item.price.toString(),
    hasVariants: Boolean(item.hasVariants),
    variants,
    imageUrl: item.imageUrl,
    isAvailable: item.isAvailable,
    categoryId: item.categoryId,
    categoryName: item.category ? item.category.name : undefined,
    createdAt: item.createdAt,
    updatedAt: item.updatedAt,
  };
}

function validatePrice(price, label = 'Price') {
  if (price === undefined || price === null || String(price).trim() === '') {
    return `${label} is required`;
  }
  const numeric = Number(price);
  if (Number.isNaN(numeric)) return `${label} must be a number`;
  if (numeric < 0) return `${label} must be 0 or greater`;
  return null;
}

/**
 * Normalizes and validates incoming variants when hasVariants === true.
 * Accepts either:
 *   variants: [{ name: 'Half', price: '120', isAvailable: true }, { name: 'Full', price: '220', isAvailable: true }]
 * or shorthand fields:
 *   halfPrice / fullPrice
 */
function parseAndValidateVariants(body) {
  let rawVariants = body.variants;

  if (!Array.isArray(rawVariants)) {
    const inferred = [];
    if (body.halfPrice !== undefined && body.halfPrice !== null && String(body.halfPrice).trim() !== '') {
      inferred.push({
        name: 'Half',
        price: body.halfPrice,
        isAvailable: body.halfAvailable === undefined ? true : Boolean(body.halfAvailable),
      });
    }
    if (body.fullPrice !== undefined && body.fullPrice !== null && String(body.fullPrice).trim() !== '') {
      inferred.push({
        name: 'Full',
        price: body.fullPrice,
        isAvailable: body.fullAvailable === undefined ? true : Boolean(body.fullAvailable),
      });
    }
    rawVariants = inferred;
  }

  if (!Array.isArray(rawVariants) || rawVariants.length === 0) {
    return { error: 'Please provide Half and/or Full variant prices when variants are enabled' };
  }

  const seenNames = new Set();
  const normalized = [];

  for (const v of rawVariants) {
    if (!v || typeof v.name !== 'string' || !v.name.trim()) {
      return { error: 'Each variant must have a valid name (Half or Full)' };
    }
    const key = v.name.trim().toLowerCase();
    const meta = ALLOWED_VARIANT_NAMES[key];
    if (!meta) {
      return { error: `Variant name "${v.name}" is not supported. Allowed variants are Half and Full.` };
    }
    if (seenNames.has(meta.name)) {
      return { error: `Duplicate variant "${meta.name}" is not allowed` };
    }
    const priceErr = validatePrice(v.price, `${meta.name} price`);
    if (priceErr) {
      return { error: priceErr };
    }
    seenNames.add(meta.name);
    normalized.push({
      name: meta.name,
      price: String(v.price).trim(),
      sortOrder: meta.sortOrder,
      isAvailable: v.isAvailable === undefined ? true : Boolean(v.isAvailable),
    });
  }

  normalized.sort((a, b) => a.sortOrder - b.sortOrder);
  return { variants: normalized };
}

async function categoryBelongsToRestaurant(categoryId, restaurantId) {
  const category = await prisma.category.findUnique({ where: { id: categoryId } });
  return !!category && category.restaurantId === restaurantId;
}

const menuItemInclude = {
  category: { select: { name: true } },
  variants: { orderBy: { sortOrder: 'asc' } },
};

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
      include: menuItemInclude,
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
      include: menuItemInclude,
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
    const hasVariants = Boolean(req.body.hasVariants);

    if (!name || !name.trim()) {
      return res.status(400).json({ success: false, message: 'Food name is required' });
    }
    if (!categoryId) {
      return res.status(400).json({ success: false, message: 'Category is required' });
    }

    let resolvedBasePrice = '0';
    let parsedVariants = [];

    if (hasVariants) {
      const result = parseAndValidateVariants(req.body);
      if (result.error) {
        return res.status(400).json({ success: false, message: result.error });
      }
      parsedVariants = result.variants;
      resolvedBasePrice = parsedVariants[0].price;
    } else {
      const priceError = validatePrice(price);
      if (priceError) {
        return res.status(400).json({ success: false, message: priceError });
      }
      resolvedBasePrice = String(price).trim();
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
        price: resolvedBasePrice,
        hasVariants,
        imageUrl: imageUrl || null,
        isAvailable: isAvailable === undefined ? true : Boolean(isAvailable),
        variants: hasVariants
          ? {
              create: parsedVariants,
            }
          : undefined,
      },
      include: menuItemInclude,
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
    const existing = await prisma.menuItem.findUnique({
      where: { id: req.params.id },
      include: { variants: true },
    });
    if (!existing || existing.restaurantId !== req.user.restaurantId) {
      return res.status(404).json({ success: false, message: 'Menu item not found' });
    }

    const { name, description, price, categoryId, imageUrl, isAvailable } = req.body;
    const nextHasVariants =
      req.body.hasVariants !== undefined ? Boolean(req.body.hasVariants) : existing.hasVariants;

    if (name !== undefined && !name.trim()) {
      return res.status(400).json({ success: false, message: 'Food name cannot be empty' });
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

    let parsedVariants = null;
    if (nextHasVariants) {
      if (
        req.body.variants !== undefined ||
        req.body.halfPrice !== undefined ||
        req.body.fullPrice !== undefined ||
        !existing.hasVariants
      ) {
        const result = parseAndValidateVariants(req.body);
        if (result.error) {
          return res.status(400).json({ success: false, message: result.error });
        }
        parsedVariants = result.variants;
      }
    } else {
      if (price !== undefined) {
        const priceError = validatePrice(price);
        if (priceError) return res.status(400).json({ success: false, message: priceError });
      } else if (existing.hasVariants) {
        return res.status(400).json({
          success: false,
          message: 'Price is required when disabling Half/Full variants',
        });
      }
    }

    const data = { hasVariants: nextHasVariants };
    if (name !== undefined) data.name = name.trim();
    if (description !== undefined) data.description = description.trim();
    if (categoryId !== undefined) data.categoryId = categoryId;
    if (imageUrl !== undefined) data.imageUrl = imageUrl || null;
    if (isAvailable !== undefined) data.isAvailable = Boolean(isAvailable);

    if (nextHasVariants && parsedVariants) {
      data.price = parsedVariants[0].price;
    } else if (!nextHasVariants && price !== undefined) {
      data.price = String(price).trim();
    }

    const updated = await prisma.$transaction(async (tx) => {
      if (!nextHasVariants) {
        await tx.menuItemVariant.deleteMany({ where: { menuItemId: existing.id } });
      } else if (parsedVariants) {
        const keepNames = parsedVariants.map((v) => v.name);
        await tx.menuItemVariant.deleteMany({
          where: {
            menuItemId: existing.id,
            name: { notIn: keepNames },
          },
        });
        for (const v of parsedVariants) {
          await tx.menuItemVariant.upsert({
            where: {
              menuItemId_name: {
                menuItemId: existing.id,
                name: v.name,
              },
            },
            update: {
              price: v.price,
              sortOrder: v.sortOrder,
              isAvailable: v.isAvailable,
            },
            create: {
              menuItemId: existing.id,
              name: v.name,
              price: v.price,
              sortOrder: v.sortOrder,
              isAvailable: v.isAvailable,
            },
          });
        }
      }

      return tx.menuItem.update({
        where: { id: existing.id },
        data,
        include: menuItemInclude,
      });
    });

    const serialized = serializeMenuItem(updated);
    res.status(200).json({
      success: true,
      message: 'Menu item updated successfully',
      data: serialized,
      menuItem: serialized,
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
      include: menuItemInclude,
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
      data: { imageUrl, url: imageUrl },
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
