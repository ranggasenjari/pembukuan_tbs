const { env } = require('../config/env');

async function processBonOcr(file) {
  if (!file) throw new Error('File gambar wajib diupload.');

  const formData = new FormData();
  const blob = new Blob([file.buffer], { type: file.mimetype || 'image/jpeg' });
  formData.append('file', blob, file.originalname || 'bon.jpg');

  const response = await fetch(env.ocrWebhookUrl, {
    method: 'POST',
    body: formData
  });

  if (!response.ok) {
    throw new Error(`OCR gagal dengan status ${response.status}`);
  }

  const payload = await response.json();
  if (Array.isArray(payload)) return payload[0] || {};
  return payload || {};
}

module.exports = { processBonOcr };
