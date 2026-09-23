const cloudinary = require('cloudinary').v2;

let configured = false;

/**
 * Lazily configures the Cloudinary SDK from environment variables on
 * first use, rather than at module-load time - this way importing this
 * file never throws just because .env hasn't been set up yet (matters
 * for scripts like seedSuperAdmin.js that don't need image upload).
 */
function ensureConfigured() {
  if (configured) return;

  const { CLOUDINARY_CLOUD_NAME, CLOUDINARY_API_KEY, CLOUDINARY_API_SECRET } = process.env;

  if (!CLOUDINARY_CLOUD_NAME || !CLOUDINARY_API_KEY || !CLOUDINARY_API_SECRET) {
    throw new Error(
      'Cloudinary is not configured - set CLOUDINARY_CLOUD_NAME, CLOUDINARY_API_KEY, ' +
      'and CLOUDINARY_API_SECRET in the environment.'
    );
  }

  cloudinary.config({
    cloud_name: CLOUDINARY_CLOUD_NAME,
    api_key: CLOUDINARY_API_KEY,
    api_secret: CLOUDINARY_API_SECRET,
  });

  configured = true;
}

/**
 * Uploads an in-memory image buffer (from multer's memory storage) to
 * Cloudinary and returns the HTTPS secure URL to store as
 * MenuItem.imageUrl. Nothing is written to Postgres by this function -
 * the caller decides what to do with the URL.
 */
async function uploadMenuItemImage(buffer, mimeType) {
  ensureConfigured();

  const dataUri = `data:${mimeType};base64,${buffer.toString('base64')}`;

  const result = await cloudinary.uploader.upload(dataUri, {
    folder: 'scanserve/menu-items',
    resource_type: 'image',
  });

  return result.secure_url;
}

async function uploadRestaurantLogo(buffer, mimeType) {
  ensureConfigured();

  const dataUri = `data:${mimeType};base64,${buffer.toString('base64')}`;

  const result = await cloudinary.uploader.upload(dataUri, {
    folder: 'scanserve/restaurants',
    resource_type: 'image',
  });

  return result.secure_url;
}

module.exports = { uploadMenuItemImage, uploadRestaurantLogo };
