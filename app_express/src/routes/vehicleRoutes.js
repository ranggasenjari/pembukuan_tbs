const express = require('express');
const { asyncHandler } = require('../middleware/asyncHandler');
const vehicleRepository = require('../repositories/vehicleRepository');

const router = express.Router();

router.get('/', asyncHandler(async (req, res) => {
  const vehicles = await vehicleRepository.listEnriched(req.supabase);
  res.render('vehicles/index', { title: 'Kendaraan', vehicles });
}));

router.get('/new', (req, res) => {
  res.render('vehicles/form', { title: 'Tambah Kendaraan', vehicle: null });
});

router.post('/', asyncHandler(async (req, res) => {
  await vehicleRepository.create(req.supabase, req.body);
  req.flash('success', 'Kendaraan berhasil disimpan.');
  res.redirect('/vehicles');
}));

router.get('/:id/edit', asyncHandler(async (req, res) => {
  const vehicle = await vehicleRepository.get(req.supabase, req.params.id);
  res.render('vehicles/form', { title: 'Edit Kendaraan', vehicle });
}));

router.put('/:id', asyncHandler(async (req, res) => {
  await vehicleRepository.update(req.supabase, req.params.id, req.body);
  req.flash('success', 'Kendaraan berhasil diperbarui.');
  res.redirect('/vehicles');
}));

router.delete('/:id', asyncHandler(async (req, res) => {
  await vehicleRepository.remove(req.supabase, req.params.id);
  req.flash('success', 'Kendaraan berhasil dihapus.');
  res.redirect('/vehicles');
}));

module.exports = router;
