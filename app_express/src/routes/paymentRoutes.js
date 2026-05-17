const express = require('express');
const { upload } = require('../config/multer');
const { asyncHandler } = require('../middleware/asyncHandler');
const paymentRepository = require('../repositories/paymentRepository');
const { uploadPublicFile } = require('../services/uploadService');
const { todayInput } = require('../services/request');

const router = express.Router();

router.get('/', asyncHandler(async (req, res) => {
  const filters = { start: req.query.start, end: req.query.end };
  const [payments, balance] = await Promise.all([
    paymentRepository.listPayments(req.supabase, filters),
    paymentRepository.getCurrentBalance(req.supabase)
  ]);
  res.render('payments/index', { title: 'Pembayaran', payments, filters, balance });
}));

router.get('/new', asyncHandler(async (req, res) => {
  const [notas, balance] = await Promise.all([
    paymentRepository.listPayableNotas(req.supabase),
    paymentRepository.getCurrentBalance(req.supabase)
  ]);
  res.render('payments/form', {
    title: 'Tambah Pembayaran',
    payment: null,
    notas,
    selectedNotaId: req.query.invoice_id,
    balance,
    today: todayInput()
  });
}));

router.post('/', upload.single('proof'), asyncHandler(async (req, res) => {
  const proofUrl = await uploadPublicFile(req.supabase, 'payments', 'payments', req.file);
  await paymentRepository.createPayment(req.supabase, req.body, proofUrl);
  req.flash('success', 'Pembayaran berhasil disimpan.');
  res.redirect('/payments');
}));

router.get('/:id/edit', asyncHandler(async (req, res) => {
  const [payment, balance] = await Promise.all([
    paymentRepository.getPayment(req.supabase, req.params.id),
    paymentRepository.getCurrentBalance(req.supabase)
  ]);
  res.render('payments/form', {
    title: 'Edit Pembayaran',
    payment,
    notas: payment.notas ? [payment.notas] : [],
    selectedNotaId: payment.invoice_id,
    balance: balance + Number(payment.amount_paid || 0),
    today: todayInput()
  });
}));

router.put('/:id', asyncHandler(async (req, res) => {
  await paymentRepository.updatePayment(req.supabase, req.params.id, req.body);
  req.flash('success', 'Pembayaran berhasil diperbarui.');
  res.redirect('/payments');
}));

router.delete('/:id', asyncHandler(async (req, res) => {
  await paymentRepository.deletePayment(req.supabase, req.params.id);
  req.flash('success', 'Pembayaran berhasil dihapus dan status nota/bon dikembalikan ke Tertagih.');
  res.redirect('/payments');
}));

module.exports = router;
