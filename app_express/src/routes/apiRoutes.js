const express = require('express');
const { upload } = require('../config/multer');
const { asyncHandler } = require('../middleware/asyncHandler');
const { processBonOcr } = require('../services/ocrService');
const { attachClient } = require('../services/realtimeService');
const ledgerRepository = require('../repositories/ledgerRepository');

const router = express.Router();

router.post('/ocr/bon', upload.single('file'), asyncHandler(async (req, res) => {
  const data = await processBonOcr(req.file);
  res.json({ data });
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
