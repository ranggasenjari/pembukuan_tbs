const express = require('express');
const { upload } = require('../config/multer');
const { asyncHandler } = require('../middleware/asyncHandler');
const bonRepository = require('../repositories/bonRepository');
const notaRepository = require('../repositories/notaRepository');
const relationAgentRepository = require('../repositories/relationAgentRepository');
const factoryRepository = require('../repositories/factoryRepository');
const vehicleRepository = require('../repositories/vehicleRepository');
const { calculateBon, parseDeductions } = require('../services/calculations');
const { uploadPublicFile } = require('../services/uploadService');
const { todayInput } = require('../services/request');

const router = express.Router();

function summarizeBons(bons) {
  return {
    totalBons: bons.length,
    unbilledBons: bons.filter((bon) => bon.status === 'BELUM_DIBAYAR').length,
    totalTonnage: bons.reduce((sum, bon) => sum + Number(bon.netto_2 || 0), 0) / 1000
  };
}

async function applyVehicleBp(supabase, body) {
  const plate = String(body.plate_number || '').replace(/\s+/g, '').toUpperCase();
  if (!plate) return;
  const vehicle = await vehicleRepository.getByPlate(supabase, plate);
  if (vehicle && vehicle.potongan_bp && (!body.bp_colt || Number(body.bp_colt) === 100000)) {
    body.bp_colt = vehicle.potongan_bp;
  }
}

function validateBonMasterSelection(body) {
  if (!body.relation_agent_id) throw new Error('Relasi / Agen wajib dipilih dari master data.');
  if (body.factory_id && !body.factory_spsi_type_id) {
    throw new Error('Jenis SPSI wajib dipilih saat Pabrik digunakan.');
  }
}

router.get('/', asyncHandler(async (req, res) => {
  const today = new Date().toISOString().slice(0, 10);
  const filters = {
    start: req.query.start || today,
    end: req.query.end || today,
    q: req.query.q,
    status: req.query.status,
    factory_id: req.query.factory_id || null
  };
  const [bons, factories] = await Promise.all([
    bonRepository.listBons(req.supabase, filters),
    factoryRepository.listFactories(req.supabase)
  ]);
  res.render('bons/index', { title: 'Slip Timbangan', bons, factories, filters, summary: summarizeBons(bons) });
}));

router.get('/new', asyncHandler(async (req, res) => {
  const [latestPrice, relationAgents, factories, vehicleMap] = await Promise.all([
    bonRepository.getLatestPrice(req.supabase),
    relationAgentRepository.listRelationAgents(req.supabase),
    factoryRepository.listFactories(req.supabase),
    vehicleRepository.getPlateMap(req.supabase)
  ]);
  const factoryDefaultPrices = {};
  factories.forEach(f => {
    const def = (f.factory_prices || []).find(p => p.is_default);
    if (def) factoryDefaultPrices[f.id] = def.price;
  });
  res.render('bons/form', {
    title: 'Tambah Slip Timbangan',
    bon: null,
    relationAgents,
    factories,
    latestPrice,
    today: todayInput(),
    vehicleMap,
    factoryDefaultPrices
  });
}));

router.post('/', upload.single('image'), asyncHandler(async (req, res) => {
  validateBonMasterSelection(req.body);
  await applyVehicleBp(req.supabase, req.body);
  const deductions = parseDeductions(req.body);
  // Harga: body > harga kendaraan > default pabrik > latest
  let bonPrice = req.body.price;
  const plate = String(req.body.plate_number || '').replace(/\s+/g, '').toUpperCase();
  if (!bonPrice && plate) {
    const vehicle = await vehicleRepository.getByPlate(req.supabase, plate);
    if (vehicle?.harga) bonPrice = vehicle.harga;
  }
  const factoryId = req.body.factory_id || null;
  if (!bonPrice && factoryId) {
    const fp = await factoryRepository.getDefaultPrice(req.supabase, factoryId);
    if (fp) bonPrice = fp;
  }
  if (!bonPrice) bonPrice = await bonRepository.getLatestPrice(req.supabase);
  const calculated = calculateBon({ ...req.body, price: bonPrice || 0, deductions });
  let imageUrl = null;
  if (req.file) {
    imageUrl = await uploadPublicFile(req.supabase, 'receipts', 'bons', req.file);
  } else if (req.body.ocr_image_url) {
    imageUrl = req.body.ocr_image_url;
  }
  const data = bonRepository.serializeBon(req.body, calculated, imageUrl);
  const bon = await bonRepository.createBon(req.supabase, data, deductions);

  if (req.body.intent === 'save_share') {
    const nota = await notaRepository.createNota(req.supabase, {
      relation_agent_id: req.body.quick_relation_agent_id || req.body.relation_agent_id,
      recipient_name: req.body.relation_name || '-'
    }, [bon.id]);
    return res.redirect(`/notas/${nota.id}?share=1`);
  }

  req.flash('success', 'Bon berhasil disimpan.');
  return res.redirect('/bons');
}));

router.get('/:id', asyncHandler(async (req, res) => {
  const [bon, related] = await Promise.all([
    bonRepository.getBon(req.supabase, req.params.id),
    bonRepository.getRelatedRecords(req.supabase, req.params.id)
  ]);
  res.render('bons/show', { title: `Bon ${bon.ticket_number || bon.plate_number}`, bon, related });
}));

router.get('/:id/edit', asyncHandler(async (req, res) => {
  const [bon, relationAgents, factories, vehicleMap] = await Promise.all([
    bonRepository.getBon(req.supabase, req.params.id),
    relationAgentRepository.listRelationAgents(req.supabase),
    factoryRepository.listFactories(req.supabase),
    vehicleRepository.getPlateMap(req.supabase)
  ]);
  const factoryDefaultPrices = {};
  factories.forEach(f => {
    const def = (f.factory_prices || []).find(p => p.is_default);
    if (def) factoryDefaultPrices[f.id] = def.price;
  });
  res.render('bons/form', { title: 'Edit Slip Timbangan', bon, relationAgents, factories, latestPrice: bon.price, today: todayInput(), vehicleMap, factoryDefaultPrices });
}));

router.put('/:id', upload.single('image'), asyncHandler(async (req, res) => {
  validateBonMasterSelection(req.body);
  await applyVehicleBp(req.supabase, req.body);
  const current = await bonRepository.getBon(req.supabase, req.params.id);
  const deductions = parseDeductions(req.body);
  const calculated = calculateBon({ ...current, ...req.body, deductions });
  const imageUrl = await uploadPublicFile(req.supabase, 'receipts', 'bons', req.file);
  const data = bonRepository.serializeBon(
    { ...current, ...req.body, status: current.status },
    calculated,
    imageUrl || current.image_url
  );
  await bonRepository.updateBon(req.supabase, req.params.id, data, deductions);

  // Jika bon sudah dalam nota, update total nota
  const related = await bonRepository.getRelatedRecords(req.supabase, req.params.id);
  for (const nota of related.notas) {
    const notaBons = await notaRepository.getNotaBons(req.supabase, nota.id);
    const newTotal = notaBons.reduce((sum, b) => sum + Number(b.total || 0), 0);
    await req.supabase.from('notas').update({ total_amount: newTotal }).eq('id', nota.id);
  }

  req.flash('success', 'Bon berhasil diperbarui.');
  res.redirect(`/bons/${req.params.id}`);
}));

// Quick inline update (AJAX)
router.patch('/:id/quick', asyncHandler(async (req, res) => {
  const current = await bonRepository.getBon(req.supabase, req.params.id);
  // Hapus field kosong dari request agar tidak menimpa data existing
  const cleanBody = {};
  Object.entries(req.body).forEach(([k, v]) => { if (v !== '' && v !== undefined) cleanBody[k] = v; });
  const body = { ...current, ...cleanBody, status: current.status };

  // Ambil factory_spsi_type_id untuk kalkulasi yang benar
  if (body.factory_spsi_type_id) {
    const fact = await factoryRepository.getFactory(req.supabase, body.factory_id);
    const spsiType = fact?.factory_spsi_types?.find(t => t.id === body.factory_spsi_type_id);
    if (spsiType) {
      body.spsi_calculation_mode = spsiType.calculation_mode;
      body.spsi_rate = spsiType.amount;
      body.biaya_bongkar = spsiType.amount;
      body.spsi_type_name = spsiType.name;
    }
  }

  const deductions = (current.bon_deductions || []).map(d => ({ label: d.label, amount: d.amount }));
  const calculated = calculateBon({ ...body, deductions });
  const data = bonRepository.serializeBon(body, calculated, current.image_url);
  await bonRepository.updateBon(req.supabase, req.params.id, data, deductions, true);

  // Jika bon sudah dalam nota, update total nota
  const related = await bonRepository.getRelatedRecords(req.supabase, req.params.id);
  for (const nota of related.notas) {
    const notaBons = await notaRepository.getNotaBons(req.supabase, nota.id);
    const newTotal = notaBons.reduce((sum, b) => sum + Number(b.total || 0), 0);
    await req.supabase.from('notas').update({ total_amount: newTotal }).eq('id', nota.id);
  }

  const updated = await bonRepository.getBon(req.supabase, req.params.id);
  res.json({ ok: true, bon: updated });
}));

router.delete('/:id', asyncHandler(async (req, res) => {
  await bonRepository.deleteBon(req.supabase, req.params.id);
  req.flash('success', 'Bon berhasil dihapus.');
  res.redirect('/bons');
}));

module.exports = router;
