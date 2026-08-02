const express = require('express');
const { asyncHandler } = require('../middleware/asyncHandler');
const notaRepository = require('../repositories/notaRepository');
const paymentRepository = require('../repositories/paymentRepository');
const relationAgentRepository = require('../repositories/relationAgentRepository');
const factoryRepository = require('../repositories/factoryRepository');
const { generateNotaPdf, generateThermalNotaPdf } = require('../services/pdfService');
const { buildNotaWhatsappMessage } = require('../services/notaWhatsapp');
const { arrayField } = require('../services/request');

const router = express.Router();

function summarizeNotas(notas) {
  const summary = {
    all: { count: notas.length, amount: 0 },
    byStatus: {}
  };

  notas.forEach((nota) => {
    const status = nota.status || 'TANPA_STATUS';
    const amount = Number(nota.total_amount || 0);
    summary.all.amount += amount;
    summary.byStatus[status] = summary.byStatus[status] || { count: 0, amount: 0 };
    summary.byStatus[status].count += 1;
    summary.byStatus[status].amount += amount;
  });

  return summary;
}

router.get('/', asyncHandler(async (req, res) => {
  const today = new Date().toISOString().slice(0, 10);
  const filters = { start: req.query.start || today, end: req.query.end || today, q: req.query.q, factory_id: req.query.factory_id || null };
  const [notas, factories] = await Promise.all([
    notaRepository.listNotas(req.supabase, filters),
    factoryRepository.listFactories(req.supabase)
  ]);
  res.render('notas/index', { title: 'Nota Transaksi', notas, factories, filters, summary: summarizeNotas(notas) });
}));

router.get('/new', asyncHandler(async (req, res) => {
  const [bons, relationAgents] = await Promise.all([
    notaRepository.getAvailableBonsForNota(req.supabase),
    relationAgentRepository.listRelationAgents(req.supabase)
  ]);
  res.render('notas/form', { title: 'Buat Nota', nota: null, bons, selectedIds: [], relationAgents });
}));

router.post('/', asyncHandler(async (req, res) => {
  const bonIds = arrayField(req.body.bon_ids);
  const nota = await notaRepository.createNota(req.supabase, req.body, bonIds);
  req.flash('success', 'Nota berhasil dibuat.');
  res.redirect(`/notas/${nota.id}`);
}));

// Gabung beberapa bon menjadi satu nota
router.post('/merge', asyncHandler(async (req, res) => {
  const bonIds = arrayField(req.body.bon_ids);
  const nota = await notaRepository.mergeBonsIntoNota(req.supabase, bonIds, req.body.relation_agent_id || null);
  if (req.headers.accept && req.headers.accept.includes('application/json')) {
    return res.json({ ok: true, nota });
  }
  req.flash('success', `${bonIds.length} bon berhasil digabung menjadi ${nota.invoice_number}.`);
  res.redirect(`/notas/${nota.id}`);
}));

router.get('/:id', asyncHandler(async (req, res) => {
  const [nota, bons, payments] = await Promise.all([
    notaRepository.getNota(req.supabase, req.params.id),
    notaRepository.getNotaBons(req.supabase, req.params.id),
    paymentRepository.listPaymentsByNota(req.supabase, req.params.id)
  ]);
  res.render('notas/show', {
    title: `Nota ${nota.invoice_number}`,
    nota,
    bons,
    payments,
    whatsappMessage: buildNotaWhatsappMessage(nota, bons),
    share: req.query.share === '1'
  });
}));

router.get('/:id/edit', asyncHandler(async (req, res) => {
  const [nota, currentBons, bons, relationAgents] = await Promise.all([
    notaRepository.getNota(req.supabase, req.params.id),
    notaRepository.getNotaBons(req.supabase, req.params.id),
    notaRepository.getAvailableBonsForNota(req.supabase, req.params.id),
    relationAgentRepository.listRelationAgents(req.supabase)
  ]);
  res.render('notas/form', {
    title: 'Edit Nota',
    nota,
    bons,
    selectedIds: currentBons.map((bon) => bon.id),
    relationAgents
  });
}));

router.put('/:id', asyncHandler(async (req, res) => {
  await notaRepository.updateNota(req.supabase, req.params.id, req.body, arrayField(req.body.bon_ids));
  req.flash('success', 'Nota berhasil diperbarui.');
  res.redirect(`/notas/${req.params.id}`);
}));

router.delete('/:id', asyncHandler(async (req, res) => {
  await notaRepository.deleteNota(req.supabase, req.params.id);
  req.flash('success', 'Nota berhasil dihapus.');
  res.redirect('/notas');
}));

router.get('/:id/pdf', asyncHandler(async (req, res) => {
  const [nota, bons] = await Promise.all([
    notaRepository.getNota(req.supabase, req.params.id),
    notaRepository.getNotaBons(req.supabase, req.params.id)
  ]);
  const buffer = await generateNotaPdf(nota, bons);
  res.setHeader('Content-Type', 'application/pdf');
  res.setHeader('Content-Disposition', `inline; filename="${nota.invoice_number}.pdf"`);
  res.send(buffer);
}));

router.get('/:id/pdf/thermal', asyncHandler(async (req, res) => {
  const [nota, bons] = await Promise.all([
    notaRepository.getNota(req.supabase, req.params.id),
    notaRepository.getNotaBons(req.supabase, req.params.id)
  ]);
  const buffer = await generateThermalNotaPdf(nota, bons[0]);
  res.setHeader('Content-Type', 'application/pdf');
  res.setHeader('Content-Disposition', `inline; filename="${nota.invoice_number}-thermal.pdf"`);
  res.send(buffer);
}));

// Send nota via WhatsApp ke nomor tertentu
router.get('/send/:id/:whatsapp_id', asyncHandler(async (req, res) => {
  const [nota, bons] = await Promise.all([
    notaRepository.getNota(req.supabase, req.params.id),
    notaRepository.getNotaBons(req.supabase, req.params.id)
  ]);
  if (!nota) return res.status(404).json({ error: 'Nota tidak ditemukan' });

  const waText = buildNotaWhatsappMessage(nota, bons);
  const chatId = req.params.whatsapp_id;

  const waRes = await fetch('http://pflkt.langkatkab.go.id:3330/api/sendText', {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'x-api-key': 'key_uchDI718apm4ceHSLZIFBPSd6X6qQuud'
    },
    body: JSON.stringify({
      chatId,
      id: null,
      reply_to: null,
      text: waText,
      linkPreview: true,
      linkPreviewHighQuality: false,
      session: 'stj'
    })
  });

  const body = await waRes.text();
  if (!waRes.ok) {
    return res.status(500).json({ error: 'Gagal kirim WA', detail: body });
  }

  res.json({ ok: true, message: 'WA terkirim', chatId });
}));

module.exports = router;
