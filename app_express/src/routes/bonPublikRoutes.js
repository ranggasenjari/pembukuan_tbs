const express = require('express');
const { asyncHandler } = require('../middleware/asyncHandler');
const bonManagementRepository = require('../repositories/bonManagementRepository');
const bonRepository = require('../repositories/bonRepository');
const factoryRepository = require('../repositories/factoryRepository');
const notaRepository = require('../repositories/notaRepository');
const paymentRelationRepository = require('../repositories/paymentRelationRepository');
const relationAgentRepository = require('../repositories/relationAgentRepository');
const paymentRepository = require('../repositories/paymentRepository');
const vehicleRepository = require('../repositories/vehicleRepository');
const { buildNotaWhatsappMessage } = require('../services/notaWhatsapp');
const { applyManagedBonUpdate } = require('../services/managedBonUpdate');
const { todayInput } = require('../services/request');

const router = express.Router();
const JAKARTA_TIME_ZONE = 'Asia/Jakarta';

async function getBonNota(supabase, bonId) {
  const bon = await bonRepository.getBon(supabase, bonId);
  const related = await bonRepository.getRelatedRecords(supabase, bon.id);
  return { bon, nota: related.notas[0] || null };
}

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

router.get('/publik', asyncHandler(async (req, res) => {
  const today = todayInput(JAKARTA_TIME_ZONE);
  const [managed, factories, paymentRelations, relationAgents] = await Promise.all([
    bonManagementRepository.listManagedBons(req.supabase, { start: today, end: today }),
    factoryRepository.listFactories(req.supabase),
    paymentRelationRepository.listPaymentRelations(req.supabase),
    relationAgentRepository.listRelationAgents(req.supabase)
  ]);

  res.render('bon/publik', {
    title: 'Update Bon Hari Ini',
    today,
    items: managed.items.filter((item) => item.bon.status !== 'LUNAS'),
    factories,
    paymentRelations,
    relationAgents
  });
}));

router.patch('/api/bon/publik/:id', asyncHandler(async (req, res) => {
  const bon = await applyManagedBonUpdate(req.supabase, req.params.id, req.body);
  res.json({ ok: true, bon });
}));

router.get('/api/bon/publik/:id/wa', asyncHandler(async (req, res) => {
  const { nota } = await getBonNota(req.supabase, req.params.id);
  if (!nota) return res.status(400).json({ error: 'Bon belum memiliki nota' });
  const bons = await notaRepository.getNotaBons(req.supabase, nota.id);
  res.json({ ok: true, text: buildNotaWhatsappMessage(nota, bons) });
}));

router.post('/api/bon/publik/:id/nota-selesai', asyncHandler(async (req, res) => {
  const { nota } = await getBonNota(req.supabase, req.params.id);
  if (!nota) return res.status(400).json({ error: 'Bon belum memiliki nota' });
  if (nota.status === 'LUNAS') return res.status(400).json({ error: 'Nota sudah lunas' });

  const payment = await paymentRepository.settleNotaWithoutProof(req.supabase, nota.id, {
    amountPaid: nota.total_amount,
    paymentDate: todayInput(JAKARTA_TIME_ZONE)
  });
  res.json({ ok: true, payment });
}));

router.post('/api/bon/publik/:id/payment-relation/new', asyncHandler(async (req, res) => {
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
  res.json({ ok: true, id: paymentRelation.id });
}));

module.exports = router;
