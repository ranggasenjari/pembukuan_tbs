const express = require('express');
const { asyncHandler } = require('../middleware/asyncHandler');
const marginRepository = require('../repositories/marginRepository');
const { arrayField, todayInput } = require('../services/request');

const router = express.Router();

router.get('/', asyncHandler(async (req, res) => {
  const filters = { start: req.query.start, end: req.query.end };
  const margins = await marginRepository.listMargins(req.supabase, filters);
  res.render('margins/index', { title: 'Margin / Offtaker', margins, filters });
}));

router.get('/new', asyncHandler(async (req, res) => {
  const payments = await marginRepository.getMarginFormPayments(req.supabase);
  res.render('margins/form', {
    title: 'Input Margin',
    margin: null,
    payments,
    selectedIds: [],
    today: todayInput()
  });
}));

router.post('/', asyncHandler(async (req, res) => {
  const margin = await marginRepository.createMargin(req.supabase, req.body, arrayField(req.body.payment_ids));
  req.flash('success', 'Margin berhasil disimpan.');
  res.redirect(`/margins/${margin.id}/edit`);
}));

router.get('/:id/edit', asyncHandler(async (req, res) => {
  const [margin, payments, selected] = await Promise.all([
    marginRepository.getMargin(req.supabase, req.params.id),
    marginRepository.getMarginFormPayments(req.supabase, req.params.id),
    marginRepository.getMarginPayments(req.supabase, req.params.id)
  ]);
  res.render('margins/form', {
    title: 'Edit Margin',
    margin,
    payments,
    selectedIds: selected.map((payment) => payment.id),
    today: todayInput()
  });
}));

router.put('/:id', asyncHandler(async (req, res) => {
  await marginRepository.updateMargin(req.supabase, req.params.id, req.body, arrayField(req.body.payment_ids));
  req.flash('success', 'Margin berhasil diperbarui.');
  res.redirect('/margins');
}));

router.delete('/:id', asyncHandler(async (req, res) => {
  await marginRepository.deleteMargin(req.supabase, req.params.id);
  req.flash('success', 'Margin dihapus dan pembayaran terkait kembali belum ter-assign.');
  res.redirect('/margins');
}));

module.exports = router;
