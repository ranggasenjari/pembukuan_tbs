const express = require('express');
const { upload } = require('../config/multer');
const { asyncHandler } = require('../middleware/asyncHandler');
const bonManagementRepository = require('../repositories/bonManagementRepository');
const bonRepository = require('../repositories/bonRepository');
const factoryRepository = require('../repositories/factoryRepository');
const notaRepository = require('../repositories/notaRepository');
const paymentRelationRepository = require('../repositories/paymentRelationRepository');
const relationAgentRepository = require('../repositories/relationAgentRepository');
const paymentRepository = require('../repositories/paymentRepository');
const subNotaRepository = require('../repositories/subNotaRepository');
const vehicleRepository = require('../repositories/vehicleRepository');
const { calculateBon } = require('../services/calculations');
const { applyManagedBonUpdate } = require('../services/managedBonUpdate');
const { buildNotaWhatsappMessage } = require('../services/notaWhatsapp');
const { todayInput } = require('../services/request');
const { uploadPublicFile } = require('../services/uploadService');

const router = express.Router();

async function ensureVehicleForBon(supabase, bon) {
  const plate = bonManagementRepository.normalizePlate(bon.plate_number);
  if (!plate) throw new Error('Plat nomor bon belum tersedia.');
  const existing = await vehicleRepository.getByPlate(supabase, plate);
  if (existing) return existing;
  return vehicleRepository.create(supabase, {
    plate_number: plate,
    driver_name: bon.driver_name || null,
    potongan_bp: bon.bp_colt || 100000,
    harga: bon.price || null
  });
}

async function recalculateBonAndNotas(supabase, bonId) {
  const bon = await bonRepository.getBon(supabase, bonId);
  const deductions = (bon.bon_deductions || []).map((item) => ({
    label: item.label,
    amount: item.amount
  }));

  const body = { ...bon };
  if (body.factory_id) {
    const factory = await factoryRepository.getFactory(supabase, body.factory_id);
    const type = (factory.factory_spsi_types || []).find((item) => item.id === body.factory_spsi_type_id);
    if (type) {
      body.spsi_type_name = type.name;
      body.spsi_calculation_mode = type.calculation_mode;
      body.spsi_rate = type.amount;
      body.biaya_bongkar = type.amount;
    }
  }

  const calculated = calculateBon({ ...body, deductions });
  const data = bonRepository.serializeBon(body, calculated, bon.image_url);
  await bonRepository.updateBon(supabase, bonId, data, deductions, true);

  const related = await bonRepository.getRelatedRecords(supabase, bonId);
  for (const nota of related.notas) {
    const notaBons = await notaRepository.getNotaBons(supabase, nota.id);
    const totalAmount = notaBons.reduce((sum, item) => sum + Number(item.total || 0), 0);
    await supabase.from('notas').update({ total_amount: totalAmount }).eq('id', nota.id);
  }

  return bonRepository.getBon(supabase, bonId);
}

router.get('/', asyncHandler(async (req, res) => {
  const today = todayInput();
  const filters = {
    start: req.query.start || today,
    end: req.query.end || today,
    q: req.query.q,
    status: req.query.status,
    factory_id: req.query.factory_id || null
  };
  const [managed, factories, paymentRelations, relationAgents] = await Promise.all([
    bonManagementRepository.listManagedBons(req.supabase, filters),
    factoryRepository.listFactories(req.supabase),
    paymentRelationRepository.listPaymentRelations(req.supabase),
    relationAgentRepository.listRelationAgents(req.supabase)
  ]);

  res.render('bon-management/index', {
    title: 'Manajemen Bon',
    items: managed.items,
    summary: managed.summary,
    factories,
    paymentRelations,
    relationAgents,
    filters,
    today
  });
}));

router.patch('/bons/:id', asyncHandler(async (req, res) => {
  const updated = await applyManagedBonUpdate(req.supabase, req.params.id, req.body);
  res.json({ ok: true, bon: updated });
}));

router.post('/bons/:id/payment-relation', asyncHandler(async (req, res) => {
  const bon = await bonRepository.getBon(req.supabase, req.params.id);
  const vehicle = await ensureVehicleForBon(req.supabase, bon);
  await paymentRelationRepository.bindVehicle(req.supabase, req.body.payment_relation_id, vehicle.id);
  if (req.headers.accept && req.headers.accept.includes('application/json')) {
    return res.json({ ok: true });
  }
  req.flash('success', 'Relasi Bayar berhasil dihubungkan ke plat bon.');
  res.redirect('/bon-management');
}));

router.post('/bons/:id/payment-relation/new', asyncHandler(async (req, res) => {
  const bon = await bonRepository.getBon(req.supabase, req.params.id);
  const vehicle = await ensureVehicleForBon(req.supabase, bon);
  const paymentRelation = await paymentRelationRepository.createPaymentRelation(req.supabase, {
    name: req.body.name,
    contact: req.body.contact,
    address: req.body.address,
    notes: req.body.notes,
    bank_name: req.body.bank_name,
    account_number: req.body.account_number,
    account_name: req.body.account_name
  });
  await paymentRelationRepository.bindVehicle(req.supabase, paymentRelation.id, vehicle.id);
  if (req.headers.accept && req.headers.accept.includes('application/json')) {
    return res.json({ ok: true, id: paymentRelation.id });
  }
  req.flash('success', 'Relasi Bayar baru berhasil dibuat dan dihubungkan.');
  res.redirect('/bon-management');
}));

router.post('/bons/:id/nota', asyncHandler(async (req, res) => {
  const bon = await bonRepository.getBon(req.supabase, req.params.id);
  const nota = await notaRepository.createNota(req.supabase, {
    relation_agent_id: bon.relation_agent_id || null,
    recipient_name: bon.relation_agent_id ? null : (bon.relation_name || bon.driver_name || bon.plate_number || '-'),
    recipient_address: bon.fruit_origin || null
  }, [bon.id]);
  req.flash('success', `Nota ${nota.invoice_number} berhasil dibuat.`);
  res.redirect('/bon-management');
}));

// Sub Nota
router.post('/bons/:id/sub-nota', asyncHandler(async (req, res) => {
  const subNota = await subNotaRepository.createForBon(req.supabase, req.params.id, req.body);
  if (req.headers.accept && req.headers.accept.includes('application/json')) {
    return res.status(201).json({ ok: true, subNota });
  }
  req.flash('success', `Sub nota ${subNota.name} berhasil ditambahkan.`);
  res.redirect('/bon-management');
}));

router.delete('/bons/:id/sub-notas/:sid', asyncHandler(async (req, res) => {
  const existing = await subNotaRepository.getSubNota(req.supabase, req.params.sid);
  await subNotaRepository.deleteSubNota(req.supabase, req.params.sid);
  if (req.headers.accept && req.headers.accept.includes('application/json')) {
    return res.json({ ok: true });
  }
  req.flash('success', `Sub nota ${existing.name} berhasil dihapus.`);
  res.redirect('/bon-management');
}));

router.post('/notas/:id/recalc', asyncHandler(async (req, res) => {
  const bons = await notaRepository.getNotaBons(req.supabase, req.params.id);
  for (const bon of bons) {
    await recalculateBonAndNotas(req.supabase, bon.id);
  }
  const updated = await notaRepository.getNota(req.supabase, req.params.id);
  res.json({ ok: true, nota: updated });
}));

router.get('/notas/:id/whatsapp', asyncHandler(async (req, res) => {
  const [nota, bons] = await Promise.all([
    notaRepository.getNota(req.supabase, req.params.id),
    notaRepository.getNotaBons(req.supabase, req.params.id)
  ]);
  res.json({ ok: true, text: buildNotaWhatsappMessage(nota, bons) });
}));

router.post('/notas/:id/payments', upload.single('proof'), asyncHandler(async (req, res) => {
  const proofUrl = await uploadPublicFile(req.supabase, 'payments', 'payments', req.file);
  await paymentRepository.createPayment(req.supabase, {
    invoice_id: req.params.id,
    payment_date: req.body.payment_date,
    amount_paid: req.body.amount_paid
  }, proofUrl);
  req.flash('success', 'Pembayaran berhasil disimpan.');
  res.redirect('/bon-management');
}));

module.exports = router;
