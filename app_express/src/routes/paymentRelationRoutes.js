const express = require('express');
const { asyncHandler } = require('../middleware/asyncHandler');
const paymentRelationRepository = require('../repositories/paymentRelationRepository');
const vehicleRepository = require('../repositories/vehicleRepository');

const router = express.Router();

router.get('/', asyncHandler(async (req, res) => {
  const filters = { q: req.query.q };
  const paymentRelations = await paymentRelationRepository.listPaymentRelations(req.supabase, filters);
  res.render('payment-relations/index', { title: 'Relasi Bayar', paymentRelations, filters });
}));

router.get('/new', asyncHandler(async (req, res) => {
  const vehicles = await vehicleRepository.list(req.supabase);
  res.render('payment-relations/form', { title: 'Tambah Relasi Bayar', paymentRelation: null, vehicles });
}));

router.post('/', asyncHandler(async (req, res) => {
  const paymentRelation = await paymentRelationRepository.createPaymentRelation(req.supabase, req.body);
  req.flash('success', 'Relasi Bayar berhasil disimpan.');
  res.redirect(`/payment-relations/${paymentRelation.id}`);
}));

router.get('/:id', asyncHandler(async (req, res) => {
  const paymentRelation = await paymentRelationRepository.getPaymentRelation(req.supabase, req.params.id);
  res.render('payment-relations/show', { title: paymentRelation.name, paymentRelation });
}));

router.get('/:id/edit', asyncHandler(async (req, res) => {
  const [paymentRelation, vehicles] = await Promise.all([
    paymentRelationRepository.getPaymentRelation(req.supabase, req.params.id),
    vehicleRepository.list(req.supabase)
  ]);
  res.render('payment-relations/form', { title: 'Edit Relasi Bayar', paymentRelation, vehicles });
}));

router.put('/:id', asyncHandler(async (req, res) => {
  await paymentRelationRepository.updatePaymentRelation(req.supabase, req.params.id, req.body);
  req.flash('success', 'Relasi Bayar berhasil diperbarui.');
  res.redirect(`/payment-relations/${req.params.id}`);
}));

router.delete('/:id', asyncHandler(async (req, res) => {
  await paymentRelationRepository.deletePaymentRelation(req.supabase, req.params.id);
  req.flash('success', 'Relasi Bayar berhasil dihapus.');
  res.redirect('/payment-relations');
}));

module.exports = router;
