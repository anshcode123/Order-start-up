const prisma = require('../lib/prisma');
const { assertActiveSubscription, checkCategoryLimit } = require('../services/subscriptionService');

async function getCategories(req, res, next) {
  try {
    const categories = await prisma.category.findMany({
      where: { restaurantId: req.user.restaurantId },
      orderBy: { name: 'asc' },
      include: { _count: { select: { menuItems: true } } },
    });

    res.status(200).json({
      success: true,
      message: 'Categories fetched successfully',
      data: categories.map((c) => ({
        id: c.id,
        name: c.name,
        description: c.description,
        menuItemCount: c._count.menuItems,
        createdAt: c.createdAt,
        updatedAt: c.updatedAt,
      })),
    });
  } catch (err) {
    next(err);
  }
}

async function createCategory(req, res, next) {
  try {
    await assertActiveSubscription(req.user.restaurantId);
    await checkCategoryLimit(req.user.restaurantId);

    const { name, description } = req.body;

    if (!name || !name.trim()) {
      return res.status(400).json({ success: false, message: 'Category name is required' });
    }

    const category = await prisma.category.create({
      data: {
        restaurantId: req.user.restaurantId,
        name: name.trim(),
        description: description ? description.trim() : '',
      },
    });

    res.status(201).json({
      success: true,
      message: 'Category created successfully',
      data: category,
      category,
    });
  } catch (err) {
    if (err.code === 'P2002') {
      return res
        .status(409)
        .json({ success: false, message: 'A category with that name already exists' });
    }
    next(err);
  }
}

async function updateCategory(req, res, next) {
  try {
    const existing = await prisma.category.findUnique({ where: { id: req.params.id } });

    if (!existing || existing.restaurantId !== req.user.restaurantId) {
      return res.status(404).json({ success: false, message: 'Category not found' });
    }

    const { name, description } = req.body;
    if (name !== undefined && !name.trim()) {
      return res.status(400).json({ success: false, message: 'Category name cannot be empty' });
    }

    const category = await prisma.category.update({
      where: { id: existing.id },
      data: {
        ...(name !== undefined && { name: name.trim() }),
        ...(description !== undefined && { description: description.trim() }),
      },
    });

    res.status(200).json({
      success: true,
      message: 'Category updated successfully',
      data: category,
      category,
    });
  } catch (err) {
    if (err.code === 'P2002') {
      return res
        .status(409)
        .json({ success: false, message: 'A category with that name already exists' });
    }
    next(err);
  }
}

async function deleteCategory(req, res, next) {
  try {
    const existing = await prisma.category.findUnique({ where: { id: req.params.id } });

    if (!existing || existing.restaurantId !== req.user.restaurantId) {
      return res.status(404).json({ success: false, message: 'Category not found' });
    }

    const menuItemCount = await prisma.menuItem.count({ where: { categoryId: existing.id } });
    if (menuItemCount > 0) {
      return res.status(409).json({
        success: false,
        message: 'Cannot delete category because menu items are assigned to it.',
      });
    }

    await prisma.category.delete({ where: { id: existing.id } });

    res.status(200).json({
      success: true,
      message: 'Category deleted successfully',
    });
  } catch (err) {
    next(err);
  }
}

module.exports = { getCategories, createCategory, updateCategory, deleteCategory };
