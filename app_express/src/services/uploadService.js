const path = require('path');

function safeFileName(fileName) {
  const parsed = path.parse(fileName || 'upload.bin');
  const base = parsed.name.replace(/[^a-zA-Z0-9_-]/g, '_').slice(0, 80) || 'upload';
  const ext = (parsed.ext || '').replace(/[^a-zA-Z0-9.]/g, '').slice(0, 12);
  return `${base}${ext}`;
}

async function uploadPublicFile(supabase, bucket, folder, file) {
  if (!file) return null;

  const storagePath = `${folder}/${Date.now()}_${safeFileName(file.originalname)}`;
  const { error } = await supabase.storage.from(bucket).upload(storagePath, file.buffer, {
    contentType: file.mimetype,
    upsert: false
  });

  if (error) throw error;

  const { data } = supabase.storage.from(bucket).getPublicUrl(storagePath);
  return data.publicUrl;
}

module.exports = { safeFileName, uploadPublicFile };
