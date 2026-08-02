const express = require('express');
const { asyncHandler } = require('../middleware/asyncHandler');
const vehicleRepository = require('../repositories/vehicleRepository');

const router = express.Router();

// Public page untuk edit BP kendaraan (tanpa auth)
router.get('/vehicles/publik', asyncHandler(async (req, res) => {
  const vehicles = await vehicleRepository.listEnriched(req.supabase);
  res.render('vehicles/publik', { title: 'Edit BP Kendaraan', vehicles });
}));

// Public API untuk update inline
router.patch('/api/vehicles/publik/:id', asyncHandler(async (req, res) => {
  const vehicle = await vehicleRepository.get(req.supabase, req.params.id);
  if (!vehicle) return res.status(404).json({ error: 'Kendaraan tidak ditemukan' });

  const oldPlate = vehicle.plate_number;

  if (req.body.plate_number !== undefined) {
    const newPlate = String(req.body.plate_number).replace(/\s+/g, '').toUpperCase();
    if (!newPlate) return res.status(400).json({ error: 'Plat nomor tidak valid' });

    await vehicleRepository.update(req.supabase, req.params.id, { ...vehicle, plate_number: newPlate });
    await req.supabase.from('bons').update({ plate_number: newPlate }).eq('plate_number', oldPlate);
    vehicle.plate_number = newPlate;
  }

  if (req.body.potongan_bp !== undefined) {
    const bp = Number(req.body.potongan_bp);
    if (isNaN(bp) || bp < 0) return res.status(400).json({ error: 'Potongan BP tidak valid' });

    await vehicleRepository.update(req.supabase, req.params.id, { ...vehicle, potongan_bp: bp, plate_number: vehicle.plate_number });
    await req.supabase.from('bons').update({ bp_colt: bp }).eq('plate_number', vehicle.plate_number);
    vehicle.potongan_bp = bp;
  }

  if (req.body.harga !== undefined) {
    const harga = req.body.harga !== null && req.body.harga !== '' ? Number(req.body.harga) : null;
    await vehicleRepository.update(req.supabase, req.params.id, { ...vehicle, harga, plate_number: vehicle.plate_number, potongan_bp: vehicle.potongan_bp });
    vehicle.harga = harga;
  }

  res.json({ ok: true, vehicle });
}));

module.exports = router;
