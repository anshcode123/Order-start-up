const prisma = require('../lib/prisma');

function serializePublicMenuItem(item) {
  const variants = Array.isArray(item.variants)
    ? item.variants.map((v) => ({
        id: v.id,
        menuItemId: v.menuItemId,
        name: v.name,
        price: v.price.toString(),
        sortOrder: v.sortOrder,
        isAvailable: v.isAvailable,
      }))
    : [];

  return {
    id: item.id,
    name: item.name,
    description: item.description,
    price: item.price.toString(),
    hasVariants: Boolean(item.hasVariants),
    variants,
    imageUrl: item.imageUrl,
    categoryId: item.categoryId,
  };
}

// GET /api/public/menu/:restaurantSlug
// No auth - this is the page a customer lands on after scanning a QR
// code. Everything returned here must be safe to show to a stranger.
async function getPublicMenu(req, res, next) {
  try {
    const { restaurantSlug } = req.params;

    const restaurant = await prisma.restaurant.findUnique({ where: { slug: restaurantSlug } });

    if (!restaurant || !restaurant.isActive) {
      return res.status(404).json({
        success: false,
        message: 'Restaurant menu is currently unavailable.',
      });
    }

    const categories = await prisma.category.findMany({
      where: { restaurantId: restaurant.id },
      orderBy: { name: 'asc' },
      include: {
        menuItems: {
          where: { isAvailable: true },
          orderBy: { name: 'asc' },
          include: {
            variants: {
              where: { isAvailable: true },
              orderBy: { sortOrder: 'asc' },
            },
          },
        },
      },
    });

    const formattedCategories = categories
      .map((category) => {
        const availableItems = category.menuItems.filter(
          (item) => !item.hasVariants || (Array.isArray(item.variants) && item.variants.length > 0)
        );
        return {
          id: category.id,
          name: category.name,
          description: category.description,
          items: availableItems.map(serializePublicMenuItem),
        };
      })
      .filter((category) => category.items.length > 0);

    const formattedRestaurant = {
      id: restaurant.id,
      name: restaurant.name,
      slug: restaurant.slug,
      description: restaurant.description,
      phone: restaurant.phone,
      address: restaurant.address,
      logoUrl: restaurant.logoUrl || null,
      requireTableNumber:
        restaurant.requireTableNumber === undefined ? true : Boolean(restaurant.requireTableNumber),
    };

    res.status(200).json({
      success: true,
      message: 'Menu fetched successfully',
      restaurant: formattedRestaurant,
      categories: formattedCategories,
      data: {
        restaurant: formattedRestaurant,
        categories: formattedCategories,
      },
    });
  } catch (err) {
    next(err);
  }
}

module.exports = { getPublicMenu };
