const prisma = require('../lib/prisma');

function serializePublicMenuItem(item) {
  return {
    id: item.id,
    name: item.name,
    description: item.description,
    // Same pattern as the admin-facing serializer in
    // controllers/menuItemController.js: Decimal -> string, never a
    // float, so the client never round-trips currency through a double.
    price: item.price.toString(),
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

    // Same 404 for "doesn't exist" and "exists but inactive" - a
    // disabled restaurant's menu must not be distinguishable from one
    // that was never there (Phase 5 spec: "Do not expose inactive
    // restaurants through the public menu").
    if (!restaurant || !restaurant.isActive) {
      return res.status(404).json({
        success: false,
        message: 'Restaurant menu is currently unavailable.',
      });
    }

    // restaurantId is derived from the slug above - never accepted from
    // the client - so this can never leak another restaurant's data.
    const categories = await prisma.category.findMany({
      where: { restaurantId: restaurant.id },
      orderBy: { name: 'asc' },
      include: {
        menuItems: {
          where: { isAvailable: true },
          orderBy: { name: 'asc' },
        },
      },
    });

    // Drop categories that end up with no available items - an empty
    // category tab a customer can tap into with nothing inside it is
    // just confusing, and the spec only ever asks to display available
    // items grouped by category, not empty categories for their own sake.
    const categoriesWithItems = categories.filter((category) => category.menuItems.length > 0);

    const formattedCategories = categoriesWithItems.map((category) => ({
      id: category.id,
      name: category.name,
      description: category.description,
      items: category.menuItems.map(serializePublicMenuItem),
    }));
    const formattedRestaurant = {
      id: restaurant.id,
      name: restaurant.name,
      slug: restaurant.slug,
      description: restaurant.description,
      phone: restaurant.phone,
      address: restaurant.address,
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
