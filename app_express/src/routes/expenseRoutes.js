const express = require('express');
const { asyncHandler } = require('../middleware/asyncHandler');
const expenseRepository = require('../repositories/expenseRepository');
const marginRepository = require('../repositories/marginRepository');
const { arrayField, todayInput } = require('../services/request');

const router = express.Router();

router.get('/', asyncHandler(async (req, res) => {
  const filters = { start: req.query.start, end: req.query.end };
  const expenses = await expenseRepository.listExpenses(req.supabase, filters);
  res.render('expenses/index', { title: 'Pengeluaran', expenses, filters });
}));

router.get('/new', asyncHandler(async (req, res) => {
  const margins = await marginRepository.listMargins(req.supabase);
  res.render('expenses/form', { title: 'Tambah Pengeluaran', margins, today: todayInput() });
}));

router.post('/', asyncHandler(async (req, res) => {
  await expenseRepository.createExpense(req.supabase, req.body, arrayField(req.body.margin_ids));
  req.flash('success', 'Pengeluaran berhasil disimpan.');
  res.redirect('/expenses');
}));

router.delete('/:id', asyncHandler(async (req, res) => {
  await expenseRepository.deleteExpense(req.supabase, req.params.id);
  req.flash('success', 'Pengeluaran berhasil dihapus.');
  res.redirect('/expenses');
}));

module.exports = router;
