/**
 * Turns a restaurant name into a URL-safe base slug.
 * Uniqueness (the "-2", "-3" suffixing) is handled separately in
 * services/restaurantService.js, since that needs a database lookup.
 *
 * "The Green Cafe" -> "the-green-cafe"
 */
function slugifyBase(name) {
  return String(name)
    .toLowerCase()
    .trim()
    .normalize('NFKD')
    .replace(/[\u0300-\u036f]/g, '') // strip accents
    .replace(/[^a-z0-9\s-]/g, '') // strip anything not alphanumeric/space/hyphen
    .trim()
    .replace(/[\s_-]+/g, '-') // collapse whitespace/underscores/hyphens
    .replace(/^-+|-+$/g, ''); // trim leading/trailing hyphens
}

module.exports = { slugifyBase };
