const express = require('express');
const { asyncHandler } = require('../middleware/asyncHandler');
const settingsRepository = require('../repositories/settingsRepository');
const factoryRepository = require('../repositories/factoryRepository');

const router = express.Router();

router.get('/', asyncHandler(async (req, res) => {
  const [ocrSettings, factories] = await Promise.all([
    settingsRepository.getOcrSettings(req.supabase),
    factoryRepository.listFactories(req.supabase).catch(() => [])
  ]);
  res.render('settings/index', {
    title: 'Setting',
    ocrSettings,
    factories
  });
}));

router.post('/ocr', asyncHandler(async (req, res) => {
  const current = await settingsRepository.getOcrSettings(req.supabase);
  const next = settingsRepository.settingsFromBody(req.body, current);
  await settingsRepository.saveOcrSettings(req.supabase, next);
  req.flash('success', 'Setting OCR berhasil disimpan.');
  res.redirect('/settings');
}));

module.exports = router;