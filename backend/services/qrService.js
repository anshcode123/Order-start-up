const QRCode = require('qrcode');

/**
 * Builds the public customer-menu URL for a restaurant slug.
 * FRONTEND_URL is required so we never hardcode a production domain -
 * see backend/.env.example.
 */
function buildMenuUrl(slug) {
  const base = process.env.FRONTEND_URL;
  if (!base) {
    throw new Error('FRONTEND_URL is not set in the environment');
  }
  return `${base.replace(/\/+$/, '')}/menu/${slug}`;
}

/**
 * Generates a QR code for a restaurant's menu URL as a base64 data URL
 * (image/png). This is generated on demand from the slug rather than
 * stored, so regenerating it later just means calling this again with
 * the same slug - nothing to keep in sync.
 */
async function generateMenuQrDataUrl(slug) {
  const menuUrl = buildMenuUrl(slug);
  const dataUrl = await QRCode.toDataURL(menuUrl, {
    margin: 2,
    width: 512,
    color: {
      dark: '#1F1B18',
      light: '#FFFFFF',
    },
  });
  return { menuUrl, dataUrl };
}

module.exports = { buildMenuUrl, generateMenuQrDataUrl };
