const express = require('express');
const { asyncHandler } = require('../middleware/asyncHandler');
const dashboardRepository = require('../repositories/dashboardRepository');
const { monthStartInput, todayInput } = require('../services/request');

const router = express.Router();

router.get('/', (req, res) => res.redirect('/dashboard'));

router.get('/dashboard', asyncHandler(async (req, res) => {
  const today = todayInput();
  const start = req.query.start || today;
  const end = req.query.end || today;
  const stats = await dashboardRepository.getDashboardStats(req.supabase, start, end);
  res.render('dashboard/index', {
    title: 'Dashboard',
    stats,
    filters: { start, end },
    presets: { today, monthStart: monthStartInput() }
  });
}));

module.exports = router;
