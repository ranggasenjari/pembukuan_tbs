const express = require('express');
const { asyncHandler } = require('../middleware/asyncHandler');
const depositRepository = require('../repositories/depositRepository');
const paymentRepository = require('../repositories/paymentRepository');

const router = express.Router();

router.get('/', asyncHandler(async (req, res) => {
  const filters = { start: req.query.start, end: req.query.end, category: req.query.category };
  const [deposits, balance] = await Promise.all([
    depositRepository.listDeposits(req.supabase, filters),
    paymentRepository.getCurrentBalance(req.supabase)
  ]);
  res.render('deposits/index', { title: 'Saldo', deposits, filters, balance });
}));

router.post('/', asyncHandler(async (req, res) => {
  await depositRepository.createDeposit(req.supabase, req.body);
  req.flash('success', 'Saldo berhasil ditambahkan.');
  res.redirect('/deposits');
}));

router.put('/:id', asyncHandler(async (req, res) => {
  await depositRepository.updateDeposit(req.supabase, req.params.id, req.body);
  req.flash('success', 'Saldo berhasil diperbarui.');
  res.redirect('/deposits');
}));

router.delete('/:id', asyncHandler(async (req, res) => {
  await depositRepository.deleteDeposit(req.supabase, req.params.id);
  req.flash('success', 'Saldo berhasil dihapus.');
  res.redirect('/deposits');
}));

module.exports = router;
