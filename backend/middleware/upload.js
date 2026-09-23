const multer = require('multer');

const ALLOWED_MIME_TYPES = ['image/jpeg', 'image/png', 'image/webp'];
const MAX_FILE_SIZE_BYTES = 5 * 1024 * 1024; // 5MB - "reasonable file size" per Phase 4 spec

/**
 * Parses a single `image` multipart field into memory (req.file.buffer)
 * rather than to disk - the buffer is handed straight to Cloudinary and
 * never touches Postgres or the filesystem.
 */
const uploadMenuItemImage = multer({
  storage: multer.memoryStorage(),
  limits: { fileSize: MAX_FILE_SIZE_BYTES },
  fileFilter: (req, file, cb) => {
    if (!ALLOWED_MIME_TYPES.includes(file.mimetype)) {
      const err = new Error('Only JPEG, PNG, and WEBP images are allowed');
      err.statusCode = 400;
      return cb(err);
    }
    cb(null, true);
  },
}).single('image');

const uploadLogoImage = multer({
  storage: multer.memoryStorage(),
  limits: { fileSize: MAX_FILE_SIZE_BYTES },
  fileFilter: (req, file, cb) => {
    if (!ALLOWED_MIME_TYPES.includes(file.mimetype)) {
      const err = new Error('Only JPEG, PNG, and WEBP images are allowed');
      err.statusCode = 400;
      return cb(err);
    }
    cb(null, true);
  },
}).single('logo');

module.exports = { uploadMenuItemImage, uploadLogoImage, MAX_FILE_SIZE_BYTES, ALLOWED_MIME_TYPES };

