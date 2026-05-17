const multer = require('multer');
const { env } = require('./env');

const upload = multer({
  storage: multer.memoryStorage(),
  limits: {
    fileSize: env.maxUploadMb * 1024 * 1024
  }
});

module.exports = { upload };
