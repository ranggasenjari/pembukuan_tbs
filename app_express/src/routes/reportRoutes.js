const express = require('express');
const { asyncHandler } = require('../middleware/asyncHandler');
const ledgerRepository = require('../repositories/ledgerRepository');
const factoryRepository = require('../repositories/factoryRepository');
const cetakanRepository = require('../repositories/cetakanRepository');
const { generateHarianPdf, generateLedgerPdf } = require('../services/pdfService');
const { monthStartInput, todayInput } = require('../services/request');

const router = express.Router();

router.get('/ledger', asyncHandler(async (req, res) => {
  const filters = {
    start: req.query.start || monthStartInput(),
    end: req.query.end || todayInput(),
    factory_id: req.query.factory_id || null
  };
  const [ledger, summary, factories] = await Promise.all([
    ledgerRepository.getLedger(req.supabase, filters),
    ledgerRepository.getSummary(req.supabase, filters.start),
    factoryRepository.listFactories(req.supabase)
  ]);
  res.render('reports/ledger', { title: 'Buku Besar', ledger, summary, filters, factories });
}));

router.get('/ledger/pdf', asyncHandler(async (req, res) => {
  const filters = {
    start: req.query.start || monthStartInput(),
    end: req.query.end || todayInput(),
    factory_id: req.query.factory_id || null
  };
  const [ledger, summary, factories] = await Promise.all([
    ledgerRepository.getLedger(req.supabase, filters),
    ledgerRepository.getSummary(req.supabase, filters.start),
    factoryRepository.listFactories(req.supabase)
  ]);
  const selectedFactory = factories.find(f => f.id === filters.factory_id);
  const pdfFilters = { ...filters, factory_name: selectedFactory?.name || null };
  const buffer = await generateLedgerPdf(ledger.inProgress, summary, pdfFilters, factories);
  res.setHeader('Content-Type', 'application/pdf');
  res.setHeader('Content-Disposition', `inline; filename="buku-besar-${filters.start}-${filters.end}.pdf"`);
  res.send(buffer);
}));

router.get('/harian', asyncHandler(async (req, res) => {
  const history = await cetakanRepository.listCetakan(req.supabase);
  res.render('reports/harian', { title: 'Cetakan', history });
}));

router.post('/harian/cetak', asyncHandler(async (req, res) => {
  const date = req.body.date || todayInput();
  const factoryId = req.body.factory_id;
  if (!factoryId) return res.status(400).json({ error: 'Pilih pabrik terlebih dahulu.' });

  const filters = { start: date, end: date, factory_id: factoryId };
  const [ledger, summary, factory] = await Promise.all([
    ledgerRepository.getLedger(req.supabase, filters),
    ledgerRepository.getSummary(req.supabase, date),
    req.supabase.from('factories').select('name').eq('id', factoryId).maybeSingle().then(r => r.data)
  ]);
  const bons = (ledger.inProgress || []).sort((a, b) => new Date(a.created_at) - new Date(b.created_at));
  const buffer = await generateHarianPdf(bons, summary, { ...filters, factory_name: factory?.name || '' }, []);

  const totalTonase = bons.reduce((sum, b) => sum + Number(b.netto_2 || 0), 0) / 1000;
  const totalAmount = bons.reduce((sum, b) => sum + Number(b.total || 0), 0);

  const filePath = `harian/${factoryId}/${date}.pdf`;
  await req.supabase.storage.from('cetakan').upload(filePath, buffer, {
    contentType: 'application/pdf',
    upsert: true
  });

  await cetakanRepository.upsertCetakan(req.supabase, {
    date,
    factory_id: factoryId,
    total_bons: bons.length,
    total_tonase: totalTonase,
    total_amount: totalAmount,
    file_path: filePath
  });

  res.setHeader('Content-Type', 'application/pdf');
  res.setHeader('Content-Disposition', `inline; filename="cetakan-harian-${date}.pdf"`);
  res.send(buffer);
}));

router.get('/harian/:id/pdf', asyncHandler(async (req, res) => {
  const record = await cetakanRepository.getCetakan(req.supabase, req.params.id);
  const { data } = req.supabase.storage.from('cetakan').getPublicUrl(record.file_path);
  res.redirect(data?.publicUrl || '/reports/harian');
}));

module.exports = router;
