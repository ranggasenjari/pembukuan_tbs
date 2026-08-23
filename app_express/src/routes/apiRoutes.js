const express = require('express');
const { upload } = require('../config/multer');
const { asyncHandler } = require('../middleware/asyncHandler');
const { processBonOcr } = require('../services/ocrService');
const factoryRepository = require('../repositories/factoryRepository');
const { attachClient } = require('../services/realtimeService');
const ledgerRepository = require('../repositories/ledgerRepository');

const router = express.Router();

router.post('/ocr/bon', upload.single('file'), asyncHandler(async (req, res) => {
  if (!req.file) return res.status(400).json({ error: 'File gambar wajib diupload.' });
  if (!req.body.factory_id) return res.status(400).json({ error: 'factory_id wajib diisi — pilih pabrik sebelum OCR.' });
  const factories = await factoryRepository.listFactories(req.supabase);
  const factory = factories.find((f) => f.id === String(req.body.factory_id).trim());
  if (!factory) return res.status(404).json({ error: 'Pabrik tidak ditemukan.' });
  const ocrResult = await processBonOcr(req.file, {
    supabase: req.supabase,
    factory_id: req.body.factory_id,
    factory_name: factory.name,
    factories
  });
  if (!ocrResult.image_url && ocrResult.image_path) {
    const { data: urlData } = req.supabase.storage.from('receipts').getPublicUrl(ocrResult.image_path);
    ocrResult.image_url = urlData?.publicUrl || null;
  }
  res.json(ocrResult);
}));

router.get('/events', (req, res) => attachClient(req, res));

router.get('/summary', asyncHandler(async (req, res) => {
  const since = req.query.since || new Date(new Date().getFullYear(), new Date().getMonth(), 1).toISOString().slice(0, 10);
  res.json(await ledgerRepository.getSummary(req.supabase, since));
}));

router.get('/ledger', asyncHandler(async (req, res) => {
  res.json(await ledgerRepository.getLedger(req.supabase, { start: req.query.start, end: req.query.end }));
}));

module.exports = router;
