const express = require('express');
const { asyncHandler } = require('../middleware/asyncHandler');
const ledgerRepository = require('../repositories/ledgerRepository');
const { monthStartInput, todayInput } = require('../services/request');

const router = express.Router();

router.get('/ledger', asyncHandler(async (req, res) => {
  const filters = {
    start: req.query.start || monthStartInput(),
    end: req.query.end || todayInput()
  };
  const ledger = await ledgerRepository.getLedger(req.supabase, filters);
  const summary = await ledgerRepository.getSummary(req.supabase, filters.start);
  res.render('reports/ledger', { title: 'Buku Besar', ledger, summary, filters });
}));

module.exports = router;
