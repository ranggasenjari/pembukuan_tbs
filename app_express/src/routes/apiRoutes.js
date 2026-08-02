const express = require('express');
const { upload } = require('../config/multer');
const { asyncHandler } = require('../middleware/asyncHandler');
const { processBonOcr } = require('../services/ocrService');
const { attachClient } = require('../services/realtimeService');
const ledgerRepository = require('../repositories/ledgerRepository');

const router = express.Router();

router.post('/ocr/bon', upload.single('file'), asyncHandler(async (req, res) => {
  if (!req.file) return res.status(400).json({ error: 'File gambar wajib diupload.' });
  const ocrResult = await processBonOcr(req.file, { supabase: req.supabase });
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
