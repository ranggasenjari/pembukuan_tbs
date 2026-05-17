const express = require('express');
const { upload } = require('../config/multer');
const { attachSystemSupabase, requireExternalApiKey } = require('../middleware/externalApiAuth');
const { asyncHandler } = require('../middleware/asyncHandler');
const bonRepository = require('../repositories/bonRepository');
const dashboardRepository = require('../repositories/dashboardRepository');
const depositRepository = require('../repositories/depositRepository');
const expenseRepository = require('../repositories/expenseRepository');
const ledgerRepository = require('../repositories/ledgerRepository');
const marginRepository = require('../repositories/marginRepository');
const notaRepository = require('../repositories/notaRepository');
const paymentRepository = require('../repositories/paymentRepository');
const { apiErrorHandler, apiNotFound, sendOk } = require('../services/apiResponse');
const { normalizeDeductions, idsFromBody } = require('../services/apiPayload');
const { resolveBonIdsByTicketNumbers } = require('../services/bonCodeService');
const { calculateBon } = require('../services/calculations');
const { processBonOcr } = require('../services/ocrService');
const { generateNotaPdf, generateThermalNotaPdf } = require('../services/pdfService');
const { monthStartInput, todayInput } = require('../services/request');
const { uploadPublicFile } = require('../services/uploadService');

function sendPdf(res, buffer, fileName, headers = {}) {
  Object.entries(headers).forEach(([name, value]) => {
    if (value !== undefined && value !== null) res.setHeader(name, String(value));
  });
  res.setHeader('Content-Type', 'application/pdf');
  res.setHeader('Content-Disposition', `inline; filename="${fileName}"`);
  return res.send(buffer);
}

function hasDeductionInput(body) {
  return body.deductions !== undefined || body.deduction_label !== undefined || body.deduction_amount !== undefined;
}

function deductionsFromBon(bon) {
  return (bon.bon_deductions || []).map((item) => ({
    label: item.label,
    amount: item.amount
  }));
}

async function createBonFromRequest(req, deps) {
  const deductions = normalizeDeductions(req.body);
  const calculated = calculateBon({ ...req.body, deductions });
  const imageUrl = await deps.uploadPublicFile(req.supabase, 'receipts', 'bons', req.file);
  const data = deps.bonRepository.serializeBon(req.body, calculated, imageUrl);
  return deps.bonRepository.createBon(req.supabase, data, deductions);
}

async function updateBonFromRequest(req, deps) {
  const current = await deps.bonRepository.getBon(req.supabase, req.params.id);
  const body = { ...current, ...req.body, status: current.status };
  const deductions = hasDeductionInput(req.body) ? normalizeDeductions(req.body) : deductionsFromBon(current);
  const calculated = calculateBon({ ...body, deductions });
  const imageUrl = await deps.uploadPublicFile(req.supabase, 'receipts', 'bons', req.file);
  const data = deps.bonRepository.serializeBon(
    body,
    calculated,
    imageUrl || current.image_url
  );
  return deps.bonRepository.updateBon(req.supabase, req.params.id, data, deductions);
}

async function resolveBonIds(req, deps) {
  return deps.resolveBonIdsByTicketNumbers(req.supabase, req.body.bon_codes);
}

function createApiV1Router(options = {}) {
  const deps = {
    authMiddleware: [requireExternalApiKey, attachSystemSupabase],
    bonRepository,
    dashboardRepository,
    depositRepository,
    expenseRepository,
    ledgerRepository,
    marginRepository,
    notaRepository,
    paymentRepository,
    processBonOcr,
    resolveBonIdsByTicketNumbers,
    uploadPublicFile,
    generateNotaPdf,
    generateThermalNotaPdf,
    ...options
  };

  const router = express.Router();
  deps.authMiddleware.forEach((middleware) => router.use(middleware));

  router.get('/bons', asyncHandler(async (req, res) => {
    const filters = {
      start: req.query.start,
      end: req.query.end,
      q: req.query.q,
      status: req.query.status
    };
    const bons = await deps.bonRepository.listBons(req.supabase, filters);
    sendOk(res, bons, { count: bons.length });
  }));

  router.post('/bons/ocr', upload.single('file'), asyncHandler(async (req, res) => {
    const data = await deps.processBonOcr(req.file);
    sendOk(res, data);
  }));

  router.post('/bons', upload.single('image'), asyncHandler(async (req, res) => {
    const bon = await createBonFromRequest(req, deps);
    sendOk(res, bon, undefined, 201);
  }));

  router.get('/bons/:id', asyncHandler(async (req, res) => {
    const [bon, related] = await Promise.all([
      deps.bonRepository.getBon(req.supabase, req.params.id),
      deps.bonRepository.getRelatedRecords(req.supabase, req.params.id)
    ]);
    sendOk(res, { bon, related });
  }));

  router.patch('/bons/:id', upload.single('image'), asyncHandler(async (req, res) => {
    const bon = await updateBonFromRequest(req, deps);
    sendOk(res, bon);
  }));

  router.delete('/bons/:id', asyncHandler(async (req, res) => {
    await deps.bonRepository.deleteBon(req.supabase, req.params.id);
    sendOk(res, { deleted: true });
  }));

  router.get('/notas', asyncHandler(async (req, res) => {
    const filters = { start: req.query.start, end: req.query.end, q: req.query.q };
    const notas = await deps.notaRepository.listNotas(req.supabase, filters);
    sendOk(res, notas, { count: notas.length });
  }));

  router.post('/notas/pdf/from-bons', asyncHandler(async (req, res) => {
    const { bonIds } = await resolveBonIds(req, deps);
    const nota = await deps.notaRepository.createNota(req.supabase, req.body, bonIds);
    const bons = await deps.notaRepository.getNotaBons(req.supabase, nota.id);
    const buffer = await deps.generateNotaPdf(nota, bons);
    sendPdf(res, buffer, `${nota.invoice_number}.pdf`, {
      'X-Nota-Id': nota.id,
      'X-Invoice-Number': nota.invoice_number
    });
  }));

  router.post('/notas', asyncHandler(async (req, res) => {
    const { bonIds, bons } = await resolveBonIds(req, deps);
    const nota = await deps.notaRepository.createNota(req.supabase, req.body, bonIds);
    sendOk(res, { nota, bons }, undefined, 201);
  }));

  router.get('/notas/:id/pdf', asyncHandler(async (req, res) => {
    const [nota, bons] = await Promise.all([
      deps.notaRepository.getNota(req.supabase, req.params.id),
      deps.notaRepository.getNotaBons(req.supabase, req.params.id)
    ]);
    const buffer = await deps.generateNotaPdf(nota, bons);
    sendPdf(res, buffer, `${nota.invoice_number}.pdf`);
  }));

  router.get('/notas/:id/pdf/thermal', asyncHandler(async (req, res) => {
    const [nota, bons] = await Promise.all([
      deps.notaRepository.getNota(req.supabase, req.params.id),
      deps.notaRepository.getNotaBons(req.supabase, req.params.id)
    ]);
    const buffer = await deps.generateThermalNotaPdf(nota, bons[0]);
    sendPdf(res, buffer, `${nota.invoice_number}-thermal.pdf`);
  }));

  router.get('/notas/:id', asyncHandler(async (req, res) => {
    const [nota, bons, payments] = await Promise.all([
      deps.notaRepository.getNota(req.supabase, req.params.id),
      deps.notaRepository.getNotaBons(req.supabase, req.params.id),
      deps.paymentRepository.listPaymentsByNota(req.supabase, req.params.id)
    ]);
    sendOk(res, { nota, bons, payments });
  }));

  router.patch('/notas/:id', asyncHandler(async (req, res) => {
    const currentNota = await deps.notaRepository.getNota(req.supabase, req.params.id);
    let bonIds;
    if (req.body.bon_codes !== undefined) {
      bonIds = (await resolveBonIds(req, deps)).bonIds;
    } else {
      const currentBons = await deps.notaRepository.getNotaBons(req.supabase, req.params.id);
      bonIds = currentBons.map((bon) => bon.id);
    }
    const nota = await deps.notaRepository.updateNota(req.supabase, req.params.id, { ...currentNota, ...req.body }, bonIds);
    sendOk(res, nota);
  }));

  router.delete('/notas/:id', asyncHandler(async (req, res) => {
    await deps.notaRepository.deleteNota(req.supabase, req.params.id);
    sendOk(res, { deleted: true });
  }));

  router.get('/payments', asyncHandler(async (req, res) => {
    const filters = { start: req.query.start, end: req.query.end };
    const [payments, balance] = await Promise.all([
      deps.paymentRepository.listPayments(req.supabase, filters),
      deps.paymentRepository.getCurrentBalance(req.supabase)
    ]);
    sendOk(res, payments, { count: payments.length, balance });
  }));

  router.get('/payments/payable-notas', asyncHandler(async (req, res) => {
    const notas = await deps.paymentRepository.listPayableNotas(req.supabase);
    sendOk(res, notas, { count: notas.length });
  }));

  router.post('/payments', upload.single('proof'), asyncHandler(async (req, res) => {
    const proofUrl = await deps.uploadPublicFile(req.supabase, 'payments', 'payments', req.file);
    const payment = await deps.paymentRepository.createPayment(req.supabase, req.body, proofUrl);
    sendOk(res, payment, undefined, 201);
  }));

  router.get('/payments/:id', asyncHandler(async (req, res) => {
    const payment = await deps.paymentRepository.getPayment(req.supabase, req.params.id);
    sendOk(res, payment);
  }));

  router.patch('/payments/:id', asyncHandler(async (req, res) => {
    const payment = await deps.paymentRepository.updatePayment(req.supabase, req.params.id, req.body);
    sendOk(res, payment);
  }));

  router.delete('/payments/:id', asyncHandler(async (req, res) => {
    await deps.paymentRepository.deletePayment(req.supabase, req.params.id);
    sendOk(res, { deleted: true });
  }));

  router.get('/deposits', asyncHandler(async (req, res) => {
    const filters = { start: req.query.start, end: req.query.end, category: req.query.category };
    const [deposits, balance] = await Promise.all([
      deps.depositRepository.listDeposits(req.supabase, filters),
      deps.paymentRepository.getCurrentBalance(req.supabase)
    ]);
    sendOk(res, deposits, { count: deposits.length, balance });
  }));

  router.post('/deposits', asyncHandler(async (req, res) => {
    const deposit = await deps.depositRepository.createDeposit(req.supabase, req.body);
    sendOk(res, deposit, undefined, 201);
  }));

  router.get('/deposits/:id', asyncHandler(async (req, res) => {
    const deposit = await deps.depositRepository.getDeposit(req.supabase, req.params.id);
    sendOk(res, deposit);
  }));

  router.patch('/deposits/:id', asyncHandler(async (req, res) => {
    const deposit = await deps.depositRepository.updateDeposit(req.supabase, req.params.id, req.body);
    sendOk(res, deposit);
  }));

  router.delete('/deposits/:id', asyncHandler(async (req, res) => {
    await deps.depositRepository.deleteDeposit(req.supabase, req.params.id);
    sendOk(res, { deleted: true });
  }));

  router.get('/margins', asyncHandler(async (req, res) => {
    const filters = { start: req.query.start, end: req.query.end };
    const margins = await deps.marginRepository.listMargins(req.supabase, filters);
    sendOk(res, margins, { count: margins.length });
  }));

  router.get('/margins/form-payments', asyncHandler(async (req, res) => {
    const payments = await deps.marginRepository.getMarginFormPayments(req.supabase, req.query.include_margin_id || null);
    sendOk(res, payments, { count: payments.length });
  }));

  router.post('/margins', asyncHandler(async (req, res) => {
    const margin = await deps.marginRepository.createMargin(req.supabase, req.body, idsFromBody(req.body, 'payment_ids'));
    sendOk(res, margin, undefined, 201);
  }));

  router.get('/margins/:id', asyncHandler(async (req, res) => {
    const [margin, payments] = await Promise.all([
      deps.marginRepository.getMargin(req.supabase, req.params.id),
      deps.marginRepository.getMarginPayments(req.supabase, req.params.id)
    ]);
    sendOk(res, { margin, payments });
  }));

  router.patch('/margins/:id', asyncHandler(async (req, res) => {
    const paymentIds = req.body.payment_ids === undefined
      ? (await deps.marginRepository.getMarginPayments(req.supabase, req.params.id)).map((payment) => payment.id)
      : idsFromBody(req.body, 'payment_ids');
    const margin = await deps.marginRepository.updateMargin(
      req.supabase,
      req.params.id,
      req.body,
      paymentIds
    );
    sendOk(res, margin);
  }));

  router.delete('/margins/:id', asyncHandler(async (req, res) => {
    await deps.marginRepository.deleteMargin(req.supabase, req.params.id);
    sendOk(res, { deleted: true });
  }));

  router.get('/expenses', asyncHandler(async (req, res) => {
    const filters = { start: req.query.start, end: req.query.end };
    const expenses = await deps.expenseRepository.listExpenses(req.supabase, filters);
    sendOk(res, expenses, { count: expenses.length });
  }));

  router.post('/expenses', asyncHandler(async (req, res) => {
    const expense = await deps.expenseRepository.createExpense(req.supabase, req.body, idsFromBody(req.body, 'margin_ids'));
    sendOk(res, expense, undefined, 201);
  }));

  router.get('/expenses/:id', asyncHandler(async (req, res) => {
    const [expense, margins] = await Promise.all([
      deps.expenseRepository.getExpense(req.supabase, req.params.id),
      deps.expenseRepository.getRelatedMargins(req.supabase, req.params.id)
    ]);
    sendOk(res, { expense, margins });
  }));

  router.patch('/expenses/:id', asyncHandler(async (req, res) => {
    const marginIds = req.body.margin_ids === undefined
      ? (await deps.expenseRepository.getRelatedMargins(req.supabase, req.params.id)).map((margin) => margin.id)
      : idsFromBody(req.body, 'margin_ids');
    const expense = await deps.expenseRepository.updateExpense(req.supabase, req.params.id, req.body, marginIds);
    sendOk(res, expense);
  }));

  router.delete('/expenses/:id', asyncHandler(async (req, res) => {
    await deps.expenseRepository.deleteExpense(req.supabase, req.params.id);
    sendOk(res, { deleted: true });
  }));

  router.get('/reports/ledger', asyncHandler(async (req, res) => {
    const data = await deps.ledgerRepository.getLedger(req.supabase, {
      start: req.query.start,
      end: req.query.end
    });
    sendOk(res, data);
  }));

  router.get('/reports/summary', asyncHandler(async (req, res) => {
    const since = req.query.since || monthStartInput();
    const data = await deps.ledgerRepository.getSummary(req.supabase, since);
    sendOk(res, data, { since });
  }));

  router.get('/dashboard/summary', asyncHandler(async (req, res) => {
    const start = req.query.start || monthStartInput();
    const end = req.query.end || todayInput();
    const data = await deps.dashboardRepository.getDashboardStats(req.supabase, start, end);
    sendOk(res, data, { start, end });
  }));

  router.use(apiNotFound);
  router.use(apiErrorHandler);

  return router;
}

const apiV1Router = createApiV1Router();

module.exports = apiV1Router;
module.exports.createApiV1Router = createApiV1Router;
