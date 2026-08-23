const express = require('express');
const { asyncHandler } = require('../middleware/asyncHandler');
const { assertNoError } = require('../repositories/base');
const ledgerRepository = require('../repositories/ledgerRepository');
const factoryRepository = require('../repositories/factoryRepository');
const cetakanRepository = require('../repositories/cetakanRepository');
const { generateHarianPdf, generateLedgerPdf } = require('../services/pdfService');
const { printCetakan, fetchPrintStatus, PrintServerError } = require('../services/printService');
const { todayInput } = require('../services/request');

const router = express.Router();

router.get('/ledger', asyncHandler(async (req, res) => {
  const filters = {
    start: req.query.start || todayInput(),
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
    start: req.query.start || todayInput(),
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

  // Relasi Bayar per plat (payment_relation_vehicles), bukan relasi agen.
  const plates = [...new Set(
    bons.map((bon) => String(bon.plate_number || '').replace(/\s+/g, '').toUpperCase()).filter(Boolean)
  )];
  const relationByPlate = {};
  if (plates.length) {
    const rows = assertNoError(
      await req.supabase
        .from('payment_relation_vehicles')
        .select('vehicles(plate_number), payment_relations(name)')
        .in('vehicles.plate_number', plates)
    );
    rows.forEach((row) => {
      const plate = String(row.vehicles?.plate_number || '').replace(/\s+/g, '').toUpperCase();
      if (plate && row.payment_relations && !relationByPlate[plate]) {
        relationByPlate[plate] = row.payment_relations;
      }
    });
  }
  bons.forEach((bon) => {
    bon.payment_relation_name = relationByPlate[
      String(bon.plate_number || '').replace(/\s+/g, '').toUpperCase()
    ]?.name || null;
  });

  const buffer = await generateHarianPdf(bons, summary, { ...filters, factory_name: factory?.name || '' }, []);

  const totalTonase = bons.reduce((sum, b) => sum + Number(b.netto_2 || 0), 0) / 1000;
  const totalAmount = bons.reduce((sum, b) => {
    const subTotal = (b.sub_notas || []).reduce((s, n) => s + Number(n.amount || 0), 0);
    return sum + Number(b.total || 0) + subTotal;
  }, 0);

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
  const { data: fileData, error } = await req.supabase.storage.from('cetakan').download(record.file_path);
  if (error || !fileData) return res.redirect('/reports/harian');

  const factory = record.factory_id
    ? await req.supabase.from('factories').select('name').eq('id', record.factory_id).maybeSingle().then(r => r.data)
    : null;
  const safeName = String(factory?.name || 'semua')
    .replace(/[^a-z0-9]+/gi, '-')
    .replace(/^-+|-+$/g, '')
    .toLowerCase() || 'factory';

  // iOS Safari tidak punya viewer untuk unduhan attachment — ia hanya menyimpan
  // file ke aplikasi Files. Untuk iOS pakai inline agar PDF terbuka (bisa di-save/share).
  const isIos = /iPad|iPhone|iPod/i.test(req.get('user-agent') || '');
  const disposition = isIos ? 'inline' : 'attachment';

  res.setHeader('Content-Type', 'application/pdf');
  res.setHeader('Content-Disposition', `${disposition}; filename="cetakan-harian-${record.date}-${safeName}.pdf"`);
  res.send(Buffer.from(await fileData.arrayBuffer()));
}));

router.post('/harian/:id/print', asyncHandler(async (req, res) => {
  const record = await cetakanRepository.getCetakan(req.supabase, req.params.id);
  const factory = record.factory_id
    ? await req.supabase.from('factories').select('name').eq('id', record.factory_id).maybeSingle().then(r => r.data)
    : null;
  const safeName = String(factory?.name || 'semua')
    .replace(/[^a-z0-9]+/gi, '-')
    .replace(/^-+|-+$/g, '')
    .toLowerCase() || 'factory';

  try {
    const result = await printCetakan({
      supabase: req.supabase,
      filePath: record.file_path,
      title: `Cetakan Harian ${record.date} - ${safeName}`
    });
    res.json({ ok: true, ...result });
  } catch (error) {
    if (error instanceof PrintServerError) {
      return res.status(error.statusCode || 502).json({ ok: false, error: error.message });
    }
    throw error;
  }
}));

router.get('/harian/:id/print-status', asyncHandler(async (req, res) => {
  await cetakanRepository.getCetakan(req.supabase, req.params.id);
  try {
    res.json({ ok: true, status: await fetchPrintStatus() });
  } catch (error) {
    if (error instanceof PrintServerError) {
      return res.status(error.statusCode || 502).json({ ok: false, error: error.message });
    }
    throw error;
  }
}));

module.exports = router;
