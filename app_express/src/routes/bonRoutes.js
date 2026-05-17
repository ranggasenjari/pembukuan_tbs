const express = require('express');
const { upload } = require('../config/multer');
const { asyncHandler } = require('../middleware/asyncHandler');
const bonRepository = require('../repositories/bonRepository');
const notaRepository = require('../repositories/notaRepository');
const { calculateBon, parseDeductions } = require('../services/calculations');
const { uploadPublicFile } = require('../services/uploadService');
const { todayInput } = require('../services/request');

const router = express.Router();

router.get('/', asyncHandler(async (req, res) => {
  const filters = {
    start: req.query.start,
    end: req.query.end,
    q: req.query.q,
    status: req.query.status
  };
  const bons = await bonRepository.listBons(req.supabase, filters);
  res.render('bons/index', { title: 'Slip Timbangan', bons, filters });
}));

router.get('/new', asyncHandler(async (req, res) => {
  const latestPrice = await bonRepository.getLatestPrice(req.supabase);
  res.render('bons/form', {
    title: 'Tambah Slip Timbangan',
    bon: null,
    latestPrice,
    today: todayInput()
  });
}));

router.post('/', upload.single('image'), asyncHandler(async (req, res) => {
  const deductions = parseDeductions(req.body);
  const calculated = calculateBon({ ...req.body, deductions });
  const imageUrl = await uploadPublicFile(req.supabase, 'receipts', 'bons', req.file);
  const data = bonRepository.serializeBon(req.body, calculated, imageUrl);
  const bon = await bonRepository.createBon(req.supabase, data, deductions);

  if (req.body.intent === 'save_share') {
    const nota = await notaRepository.createNota(req.supabase, {
      recipient_name: req.body.quick_recipient_name || req.body.relation_name || '-',
      recipient_address: req.body.quick_recipient_address || ''
    }, [bon.id]);
    return res.redirect(`/notas/${nota.id}?share=1`);
  }

  req.flash('success', 'Bon berhasil disimpan.');
  return res.redirect('/bons');
}));

router.get('/:id', asyncHandler(async (req, res) => {
  const [bon, related] = await Promise.all([
    bonRepository.getBon(req.supabase, req.params.id),
    bonRepository.getRelatedRecords(req.supabase, req.params.id)
  ]);
  res.render('bons/show', { title: `Bon ${bon.ticket_number || bon.plate_number}`, bon, related });
}));

router.get('/:id/edit', asyncHandler(async (req, res) => {
  const bon = await bonRepository.getBon(req.supabase, req.params.id);
  res.render('bons/form', { title: 'Edit Slip Timbangan', bon, latestPrice: bon.price, today: todayInput() });
}));

router.put('/:id', upload.single('image'), asyncHandler(async (req, res) => {
  const current = await bonRepository.getBon(req.supabase, req.params.id);
  const deductions = parseDeductions(req.body);
  const calculated = calculateBon({ ...req.body, deductions });
  const imageUrl = await uploadPublicFile(req.supabase, 'receipts', 'bons', req.file);
  const data = bonRepository.serializeBon(
    { ...req.body, status: current.status },
    calculated,
    imageUrl || current.image_url
  );
  await bonRepository.updateBon(req.supabase, req.params.id, data, deductions);
  req.flash('success', 'Bon berhasil diperbarui.');
  res.redirect(`/bons/${req.params.id}`);
}));

router.delete('/:id', asyncHandler(async (req, res) => {
  await bonRepository.deleteBon(req.supabase, req.params.id);
  req.flash('success', 'Bon berhasil dihapus.');
  res.redirect('/bons');
}));

module.exports = router;
