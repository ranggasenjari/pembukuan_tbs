const express = require('express');
const { asyncHandler } = require('../middleware/asyncHandler');
const vehicleRepository = require('../repositories/vehicleRepository');
const paymentRelationRepository = require('../repositories/paymentRelationRepository');
const { assertNoError } = require('../repositories/base');

const router = express.Router();

router.get('/', asyncHandler(async (req, res) => {
  const q = req.query.q || '';
  const [vehicles, paymentRelations] = await Promise.all([
    vehicleRepository.listEnriched(req.supabase, { q }),
    paymentRelationRepository.listPaymentRelations(req.supabase)
  ]);
  res.render('vehicles/index', { title: 'Kendaraan', vehicles, paymentRelations, q });
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

// Update inline: potongan BP, harga (fix/offset), dan relasi bayar terkait plat
router.post('/:id/inline', asyncHandler(async (req, res) => {
  const vehicle = await vehicleRepository.get(req.supabase, req.params.id);
  const body = {
    plate_number: vehicle.plate_number,
    driver_name: vehicle.driver_name,
    is_super: vehicle.is_super ? '1' : '',
    potongan_bp: req.body.potongan_bp ?? vehicle.potongan_bp,
    harga: req.body.harga !== undefined && req.body.harga !== ''
      ? req.body.harga
      : vehicle.harga
  };
  await vehicleRepository.update(req.supabase, req.params.id, body);

  // Relasi bayar: kosongkan = lepas, ada = ikat ke plat
  const relationId = String(req.body.payment_relation_id || '').trim();
  if (relationId) {
    await paymentRelationRepository.bindVehicle(req.supabase, relationId, req.params.id);
  } else {
    assertNoError(
      await req.supabase.from('payment_relation_vehicles').delete().eq('vehicle_id', req.params.id)
    );
  }
  req.flash('success', 'Kendaraan diperbarui.');
  res.redirect('/vehicles');
}));

// Buat relasi bayar baru lalu ikat langsung ke kendaraan ini
router.post('/:id/payment-relation/new', asyncHandler(async (req, res) => {
  const paymentRelation = await paymentRelationRepository.createPaymentRelation(req.supabase, req.body);
  await paymentRelationRepository.bindVehicle(req.supabase, paymentRelation.id, req.params.id);
  if (req.headers.accept && req.headers.accept.includes('application/json')) {
    return res.json({ ok: true, id: paymentRelation.id });
  }
  req.flash('success', 'Relasi Bayar baru berhasil dibuat dan dihubungkan.');
  res.redirect('/vehicles');
}));

module.exports = router;