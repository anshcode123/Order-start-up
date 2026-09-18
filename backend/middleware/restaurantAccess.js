/**
 * Guards any route shaped like /:id where the id is a restaurant id.
 * - SUPER_ADMIN: always allowed.
 * - RESTAURANT_ADMIN: allowed ONLY when req.params.id matches
 *   req.user.restaurant - the restaurant id from their verified JWT/DB
 *   record, never a value the client supplies. This is what stops
 *   Restaurant A's admin from reading Restaurant B by editing the URL.
 *
 * Use AFTER protect(). Any other role is rejected.
 */
function restrictToOwnRestaurant(req, res, next) {
  if (!req.user) {
    return res.status(401).json({ success: false, message: 'Not authenticated' });
  }

  if (req.user.role === 'SUPER_ADMIN') {
    return next();
  }

  if (req.user.role === 'RESTAURANT_ADMIN') {
    const ownRestaurantId = req.user.restaurant ? req.user.restaurant.toString() : null;

    if (!ownRestaurantId || ownRestaurantId !== req.params.id) {
      return res
        .status(403)
        .json({ success: false, message: 'Forbidden: you do not have access to this restaurant' });
    }
    return next();
  }

  return res.status(403).json({ success: false, message: 'Forbidden' });
}

module.exports = { restrictToOwnRestaurant };
