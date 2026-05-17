const express = require('express');
const { asyncHandler } = require('../middleware/asyncHandler');
const notaRepository = require('../repositories/notaRepository');
const paymentRepository = require('../repositories/paymentRepository');
const { generateNotaPdf, generateThermalNotaPdf } = require('../services/pdfService');
const { arrayField } = require('../services/request');

const router = express.Router();

router.get('/', asyncHandler(async (req, res) => {
  const filters = { start: req.query.start, end: req.query.end, q: req.query.q };
  const notas = await notaRepository.listNotas(req.supabase, filters);
  res.render('notas/index', { title: 'Nota Transaksi', notas, filters });
}));

router.get('/new', asyncHandler(async (req, res) => {
  const bons = await notaRepository.getAvailableBonsForNota(req.supabase);
  res.render('notas/form', { title: 'Buat Nota', nota: null, bons, selectedIds: [] });
}));

router.post('/', asyncHandler(async (req, res) => {
  const bonIds = arrayField(req.body.bon_ids);
  const nota = await notaRepository.createNota(req.supabase, req.body, bonIds);
  req.flash('success', 'Nota berhasil dibuat.');
  res.redirect(`/notas/${nota.id}`);
}));

router.get('/:id', asyncHandler(async (req, res) => {
  const [nota, bons, payments] = await Promise.all([
    notaRepository.getNota(req.supabase, req.params.id),
    notaRepository.getNotaBons(req.supabase, req.params.id),
    paymentRepository.listPaymentsByNota(req.supabase, req.params.id)
  ]);
  res.render('notas/show', { title: `Nota ${nota.invoice_number}`, nota, bons, payments, share: req.query.share === '1' });
}));

router.get('/:id/edit', asyncHandler(async (req, res) => {
  const [nota, currentBons, bons] = await Promise.all([
    notaRepository.getNota(req.supabase, req.params.id),
    notaRepository.getNotaBons(req.supabase, req.params.id),
    notaRepository.getAvailableBonsForNota(req.supabase, req.params.id)
  ]);
  res.render('notas/form', {
    title: 'Edit Nota',
    nota,
    bons,
    selectedIds: currentBons.map((bon) => bon.id)
  });
}));

router.put('/:id', asyncHandler(async (req, res) => {
  await notaRepository.updateNota(req.supabase, req.params.id, req.body, arrayField(req.body.bon_ids));
  req.flash('success', 'Nota berhasil diperbarui.');
  res.redirect(`/notas/${req.params.id}`);
}));

router.delete('/:id', asyncHandler(async (req, res) => {
  await notaRepository.deleteNota(req.supabase, req.params.id);
  req.flash('success', 'Nota berhasil dihapus.');
  res.redirect('/notas');
}));

router.get('/:id/pdf', asyncHandler(async (req, res) => {
  const [nota, bons] = await Promise.all([
    notaRepository.getNota(req.supabase, req.params.id),
    notaRepository.getNotaBons(req.supabase, req.params.id)
  ]);
  const buffer = await generateNotaPdf(nota, bons);
  res.setHeader('Content-Type', 'application/pdf');
  res.setHeader('Content-Disposition', `inline; filename="${nota.invoice_number}.pdf"`);
  res.send(buffer);
}));

router.get('/:id/pdf/thermal', asyncHandler(async (req, res) => {
  const [nota, bons] = await Promise.all([
    notaRepository.getNota(req.supabase, req.params.id),
    notaRepository.getNotaBons(req.supabase, req.params.id)
  ]);
  const buffer = await generateThermalNotaPdf(nota, bons[0]);
  res.setHeader('Content-Type', 'application/pdf');
  res.setHeader('Content-Disposition', `inline; filename="${nota.invoice_number}-thermal.pdf"`);
  res.send(buffer);
}));

module.exports = router;
