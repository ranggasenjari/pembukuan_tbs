const express = require('express');
const { upload } = require('../config/multer');
const { attachSystemSupabase, requireExternalApiKey } = require('../middleware/externalApiAuth');
const { asyncHandler } = require('../middleware/asyncHandler');
const bonRepository = require('../repositories/bonRepository');
const dashboardRepository = require('../repositories/dashboardRepository');
const depositRepository = require('../repositories/depositRepository');
const expenseRepository = require('../repositories/expenseRepository');
const factoryRepository = require('../repositories/factoryRepository');
const vehicleRepository = require('../repositories/vehicleRepository');
const ledgerRepository = require('../repositories/ledgerRepository');
const marginRepository = require('../repositories/marginRepository');
const notaRepository = require('../repositories/notaRepository');
const paymentRepository = require('../repositories/paymentRepository');
const paymentRelationRepository = require('../repositories/paymentRelationRepository');
const relationAgentRepository = require('../repositories/relationAgentRepository');
const { apiError, apiErrorHandler, apiNotFound, sendOk } = require('../services/apiResponse');
const { normalizeDeductions, idsFromBody } = require('../services/apiPayload');
const { resolveBonIdsByTicketNumbers } = require('../services/bonCodeService');
const { calculateBon } = require('../services/calculations');
const { processBonOcr } = require('../services/ocrService');
const { generateNotaPdf, generateThermalNotaPdf } = require('../services/pdfService');
const { monthStartInput, todayInput } = require('../services/request');
const { uploadPublicFile } = require('../services/uploadService');
const { buildNotaWhatsappMessage, buildPaymentInfoMessage } = require('../services/notaWhatsapp');

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
  const { bonPrice } = await enrichBonInput(req.body, deps, req.supabase);
  const calculated = calculateBon({ ...req.body, price: bonPrice, deductions });
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

async function enrichBonInput(body, deps, supabase) {
  const plate = String(body.plate_number || '').replace(/\s+/g, '').toUpperCase();
  let vehicle = null;
  if (plate) {
    vehicle = await deps.vehicleRepository.getByPlate(supabase, plate);
  }

  // BP dari kendaraan
  if (vehicle && vehicle.potongan_bp && (!body.bp_colt || Number(body.bp_colt) === 100000)) {
    body.bp_colt = vehicle.potongan_bp;
  }

  // BP berdasarkan tonase netto_1 (fallback jika vehicle.potongan_bp tidak ada atau 0)
  if (!body.bp_colt || Number(body.bp_colt) === 100000) {
    const n1 = Number(body.netto_1) || 0;
    if (n1 > 0 && n1 < 3500) body.bp_colt = 50000;
    else if (n1 >= 3500 && n1 < 6000) body.bp_colt = 70000;
    else if (n1 >= 6000) body.bp_colt = 100000;
  }

  // Harga: body.price > SUPER (jika is_super) > vehicle.harga (fixed) > default pabrik > vehicle.harga (offset) > latest
  let bonPrice = body.price;
  const factoryId = body.factory_id || null;
  let vehicleHargaIsOffset = false;
  if (!bonPrice && vehicle && vehicle.harga !== null && vehicle.harga !== undefined && vehicle.harga !== 0) {
    if (vehicle.harga >= -100 && vehicle.harga <= 100) {
      vehicleHargaIsOffset = true;
    } else {
      bonPrice = vehicle.harga;
    }
  }
  if (!bonPrice && factoryId) {
    const factoryPrice = await deps.factoryRepository.getDefaultPrice(supabase, factoryId);
    if (factoryPrice) bonPrice = factoryPrice;
  }
  // SUPER override: body.is_super || vehicle.is_super → cari harga "SUPER" di factory_prices
  if (factoryId) {
    const isSuper = body.is_super === true || body.is_super === '1' || body.is_super === 'true' || (vehicle && vehicle.is_super === true);
    if (isSuper) {
      const factories = await deps.factoryRepository.listFactories(supabase);
      const factory = factories.find(f => f.id === factoryId);
      const superPrice = (factory?.factory_prices || []).find(p => String(p.name || '').trim().toUpperCase() === 'SUPER');
      if (superPrice && superPrice.price > 0) {
        bonPrice = superPrice.price;
        vehicleHargaIsOffset = false;
      }
    }
  }
  if (vehicleHargaIsOffset && bonPrice !== null) {
    bonPrice = bonPrice + vehicle.harga;
  }
  const latestPrice = !bonPrice ? await deps.bonRepository.getLatestPrice(supabase) : 0;

  // Auto-register kendaraan baru
  if (plate) {
    const existing = vehicle || await deps.vehicleRepository.getByPlate(supabase, plate);
    if (!existing) {
      await deps.vehicleRepository.create(supabase, {
        plate_number: plate,
        driver_name: body.driver_name || null,
        potongan_bp: 100000
      });
    }
  }

  return { bonPrice: bonPrice || latestPrice || 0, vehicle };
}

function createApiV1Router(options = {}) {
  const deps = {
    authMiddleware: [requireExternalApiKey, attachSystemSupabase],
    bonRepository,
    dashboardRepository,
    depositRepository,
    expenseRepository,
    factoryRepository,
    ledgerRepository,
    marginRepository,
    notaRepository,
    paymentRepository,
    paymentRelationRepository,
    relationAgentRepository,
    vehicleRepository,
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
    const data = await deps.processBonOcr(req.file, { supabase: req.supabase });
    sendOk(res, data);
  }));

  router.post('/bons', upload.single('image'), asyncHandler(async (req, res) => {
    const bon = await createBonFromRequest(req, deps);
    sendOk(res, bon, undefined, 201);
  }));

  router.post('/bons/from-ocr', asyncHandler(async (req, res) => {
    const body = Array.isArray(req.body) ? req.body[0] : req.body;
    if (!body.plate_number || !body.bon_date) {
      throw apiError(400, 'VALIDATION_ERROR', 'plate_number dan bon_date wajib diisi.');
    }

    // Cek duplikat: plate_number + netto_1 + netto_2 + bon_date yang sama
    const dupPlate = String(body.plate_number || '').replace(/\s+/g, '').toUpperCase();
    const dupN1 = Number(body.netto_1) || 0;
    const dupN2 = Number(body.netto_2) || 0;
    const dupDate = String(body.bon_date || '').slice(0, 10);
    if (dupPlate && dupN1 && dupN2 && dupDate) {
      const { data: existingBons, error: dupError } = await req.supabase
        .from('bons')
        .select('id')
        .eq('plate_number', dupPlate)
        .eq('netto_1', dupN1)
        .eq('netto_2', dupN2)
        .eq('bon_date', dupDate)
        .limit(1);
      if (dupError) {
        console.error('OCR: duplicate check error', dupError);
      } else if (existingBons && existingBons.length > 0) {
        console.log('OCR: duplicate bon detected, skipping insert', dupPlate, dupN1, dupN2, dupDate);
        // Kirim WA "Bon ini sudah ada di sistem"
        try {
          const dupPayload = {
            chatId: '120363402074969776@g.us',
            id: null,
            reply_to: null,
            text: 'Bon ini sudah ada di sistem',
            linkPreview: true,
            linkPreviewHighQuality: false,
            session: 'stj'
          };
          const dupRes = await fetch('http://pflkt.langkatkab.go.id:3330/api/sendText', {
            method: 'POST',
            headers: {
              'Content-Type': 'application/json',
              'x-api-key': 'key_uchDI718apm4ceHSLZIFBPSd6X6qQuud'
            },
            body: JSON.stringify(dupPayload)
          });
          console.log('OCR: duplicate WA response status', dupRes.status);
        } catch (dupWaError) {
          console.error('OCR: duplicate WA send error', dupWaError.message);
        }
        return sendOk(res, { duplicate: true, message: 'Bon ini sudah ada di sistem' }, undefined, 200);
      }
    }

    // Override factory_name berdasarkan prefix ticket_number
    const ticketPrefix = String(body.ticket_number || '').trim().toUpperCase();
    if (ticketPrefix.startsWith('TBS')) {
      body.factory_name = 'PT. CIPTA CHEMICAL MEDAN OIL';
    } else if (ticketPrefix.startsWith('HAF')) {
      body.factory_name = 'PT. AWAN ALAM ANUGRA';
    }

    // Cari relasi dari nama atau gunakan langsung jika dikirim
    let relationAgentId = body.relation_agent_id || null;
    if (!relationAgentId && body.relation_name) {
      const agents = await deps.relationAgentRepository.listRelationAgents(req.supabase);
      const match = agents.find(
        (a) => String(a.name || '').trim().toUpperCase() === String(body.relation_name).trim().toUpperCase()
      );
      if (match) relationAgentId = match.id;
    }

    // Cari pabrik; jika dikirim langsung, gunakan factory_spsi_type_id langsung
    let factoryId = null;
    let factorySpsiTypeId = body.factory_spsi_type_id || null;
    let spsiTypeName = body.spsi_type_name || '';
    let spsiCalcMode = body.spsi_calculation_mode || 'PER_KG';
    let spsiRate = parseInt(body.spsi_rate) || 12;
    let biayaBongkar = parseInt(body.spsi_rate) || 12;

    if (!factorySpsiTypeId) {
      // Fallback: cari pabrik dari nama
      const factories = await deps.factoryRepository.listFactories(req.supabase);
      let selectedFactory = null;

      if (body.factory_name) {
        selectedFactory = factories.find(
          (f) => String(f.name || '').trim().toUpperCase() === String(body.factory_name).trim().toUpperCase()
        );
      }
      if (!selectedFactory && factories.length > 0) {
        selectedFactory = factories[factories.length - 1];
      }

      if (selectedFactory) {
        factoryId = selectedFactory.id;
        const types = selectedFactory.factory_spsi_types || [];
        if (types.length > 0) {
          const lastType = types[types.length - 1];
          factorySpsiTypeId = lastType.id;
          spsiTypeName = lastType.name || '';
          spsiCalcMode = lastType.calculation_mode || 'PER_KG';
          spsiRate = parseInt(lastType.amount) || 12;
          biayaBongkar = spsiRate;
        }
      }
    } else {
      // factory_spsi_type_id sudah dikirim, cari factory_id dari nama
      if (body.factory_name) {
        const factories = await deps.factoryRepository.listFactories(req.supabase);
        const match = factories.find(
          (f) => String(f.name || '').trim().toUpperCase() === String(body.factory_name).trim().toUpperCase()
        );
        if (match) factoryId = match.id;
      }
    }

    // Harga: body.price > SUPER (jika is_super) > vehicle.harga (fixed) > default pabrik > vehicle.harga (offset) > latest
    const ocrPlate = String(body.plate_number || '').replace(/\s+/g, '').toUpperCase();
    let vehicle = null;
    if (ocrPlate) {
      vehicle = await vehicleRepository.getByPlate(req.supabase, ocrPlate);
    }
    let bonPrice = body.price;
    let vehicleHargaIsOffset = false;

    if (!bonPrice && vehicle && vehicle.harga !== null && vehicle.harga !== undefined && vehicle.harga !== 0) {
      if (vehicle.harga >= -100 && vehicle.harga <= 100) {
        vehicleHargaIsOffset = true;
      } else {
        bonPrice = vehicle.harga;
      }
    }

    if (!bonPrice && factoryId) {
      const factoryPrice = await deps.factoryRepository.getDefaultPrice(req.supabase, factoryId);
      if (factoryPrice) bonPrice = factoryPrice;
    }

    // SUPER override: body.is_super || vehicle.is_super → cari harga "SUPER" di factory_prices
    if (factoryId) {
      const isSuper = body.is_super === true || body.is_super === '1' || body.is_super === 'true' || (vehicle && vehicle.is_super === true);
      if (isSuper) {
        const factories = await deps.factoryRepository.listFactories(req.supabase);
        const factory = factories.find(f => f.id === factoryId);
        const superPrice = (factory?.factory_prices || []).find(p => String(p.name || '').trim().toUpperCase() === 'SUPER');
        if (superPrice && superPrice.price > 0) {
          bonPrice = superPrice.price;
          vehicleHargaIsOffset = false;
        }
      }
    }

    if (vehicleHargaIsOffset && bonPrice !== null) {
      bonPrice = bonPrice + vehicle.harga;
    }
    const latestPrice = !bonPrice ? await deps.bonRepository.getLatestPrice(req.supabase) : 0;

    // Ambil potongan BP dari data kendaraan jika ada
    if (vehicle && vehicle.potongan_bp && (!body.bp_colt || Number(body.bp_colt) === 100000)) {
      body.bp_colt = vehicle.potongan_bp;
    }

    // BP berdasarkan tonase netto_1 (fallback jika vehicle.potongan_bp tidak ada atau 0)
    if (!body.bp_colt || Number(body.bp_colt) === 100000) {
      const n1 = Number(body.netto_1) || 0;
      if (n1 > 0 && n1 < 3500) body.bp_colt = 50000;
      else if (n1 >= 3500 && n1 < 6000) body.bp_colt = 70000;
      else if (n1 >= 6000) body.bp_colt = 100000;
    }

    const deductions = [];
    const calculated = calculateBon({
      ...body,
      factory_id: factoryId,
      price: bonPrice || latestPrice || 0,
      dp: body.dp || 0,
      biaya_bongkar: biayaBongkar,
      spsi_calculation_mode: spsiCalcMode,
      spsi_rate: spsiRate,
      bp_colt: body.bp_colt || 100000,
      deductions
    });

    // Image URL dari path yang sudah diupload n8n
    let imageUrl = null;
    if (body.path) {
      const { data: urlData } = req.supabase.storage.from('receipts').getPublicUrl(body.path);
      imageUrl = urlData?.publicUrl || null;
    }

    const data = deps.bonRepository.serializeBon({
      ticket_number: body.ticket_number,
      bon_date: body.bon_date,
      plate_number: body.plate_number,
      driver_name: body.driver_name,
      relation_name: body.relation_name,
      relation_agent_id: relationAgentId,
      factory_id: factoryId,
      factory_spsi_type_id: factorySpsiTypeId,
      spsi_type_name: spsiTypeName,
      fruit_origin: body.fruit_origin,
      chat_id: body.chat_id,
      message_id: body.message_id,
      notes: body.catatan || body.notes
    }, calculated, imageUrl);

    const bon = await deps.bonRepository.createBon(req.supabase, data, deductions);

    // Auto-register kendaraan baru jika plat belum terdaftar
    const plate = String(body.plate_number || '').replace(/\s+/g, '').toUpperCase();
    if (plate) {
      const existing = await vehicleRepository.getByPlate(req.supabase, plate);
      if (!existing) {
        await vehicleRepository.create(req.supabase, {
          plate_number: plate,
          driver_name: body.driver_name || null,
          potongan_bp: 100000
        });
      }
    }

    // Auto-generate nota dan kirim ke WhatsApp
    console.log('OCR: starting WA send for bon', bon.id);
    try {
      const relationName = body.relation_name || body.driver_name || '-';
      console.log('OCR: creating nota for', relationName);
      const nota = await deps.notaRepository.createNota(req.supabase, {
        relation_agent_id: relationAgentId,
        recipient_name: relationName,
        recipient_address: body.fruit_origin || null
      }, [bon.id]);
      console.log('OCR: nota created', nota?.id);

      const notaBons = await deps.notaRepository.getNotaBons(req.supabase, nota.id);
      const waText = buildNotaWhatsappMessage(nota, notaBons);
      console.log('OCR: waText length', waText.length);

      const waPayload = {
        chatId: '120363402074969776@g.us',
        id: null,
        reply_to: null,
        text: waText,
        linkPreview: true,
        linkPreviewHighQuality: false,
        session: 'stj'
      };
      console.log('OCR: sending WA to', waPayload.chatId);

      const waRes = await fetch('http://pflkt.langkatkab.go.id:3330/api/sendText', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'x-api-key': 'key_uchDI718apm4ceHSLZIFBPSd6X6qQuud'
        },
        body: JSON.stringify(waPayload)
      });
      console.log('OCR: WA response status', waRes.status);
      if (!waRes.ok) {
        const waBody = await waRes.text();
        console.error('WhatsApp API error:', waRes.status, waBody);
      }

      // Cari relasi bayar berdasarkan plat nomor
      try {
        const paymentRel = await deps.paymentRelationRepository.findByPlate(req.supabase, plate);
        if (paymentRel) {
          console.log('OCR: payment relation found for', plate, '-', paymentRel.name);
          const payText = buildPaymentInfoMessage(paymentRel);
          const payPayload = {
            chatId: '120363402074969776@g.us',
            id: null,
            reply_to: null,
            text: payText,
            linkPreview: true,
            linkPreviewHighQuality: false,
            session: 'stj'
          };
          const payRes = await fetch('http://pflkt.langkatkab.go.id:3330/api/sendText', {
            method: 'POST',
            headers: {
              'Content-Type': 'application/json',
              'x-api-key': 'key_uchDI718apm4ceHSLZIFBPSd6X6qQuud'
            },
            body: JSON.stringify(payPayload)
          });
          console.log('OCR: payment WA response', payRes.status);
        } else {
          console.log('OCR: no payment relation for plate', plate);
        }
      } catch (payError) {
        console.error('OCR: payment relation WA error:', payError.message);
      }
    } catch (waError) {
      console.error('WhatsApp send error:', waError.message);
    }
    console.log('OCR: WA flow complete');

    sendOk(res, bon, undefined, 201);
  }));

  router.get('/bons/:id', asyncHandler(async (req, res) => {
    const [bon, related] = await Promise.all([
      deps.bonRepository.getBon(req.supabase, req.params.id),
      deps.bonRepository.getRelatedRecords(req.supabase, req.params.id)
    ]);
    sendOk(res, { bon, related });
  }));

  router.get('/bons/recalc/:id', asyncHandler(async (req, res) => {
    let bon;
    try {
      bon = await deps.bonRepository.getBon(req.supabase, req.params.id);
    } catch (e) {
      return sendOk(res, null, { error: 'Bon tidak ditemukan' }, 404);
    }

    const deductions = (bon.bon_deductions || []).map(d => ({ label: d.label, amount: d.amount }));
    const factoryId = bon.factory_id;
    if (factoryId) {
      const factory = await deps.factoryRepository.getFactory(req.supabase, factoryId);
      const spsiType = (factory?.factory_spsi_types || []).find(t => t.id === bon.factory_spsi_type_id);
      if (spsiType) {
        bon.spsi_calculation_mode = spsiType.calculation_mode;
        bon.spsi_rate = spsiType.amount;
        bon.biaya_bongkar = spsiType.amount;
      }
    }

    const calculated = calculateBon({ ...bon, pph: undefined, uang_minum: undefined, deductions });
    const { pph, uang_minum, total, spsi_amount } = calculated;

    const { error: bonError } = await req.supabase.from('bons').update({ pph, uang_minum, total, spsi_amount }).eq('id', req.params.id);
    if (bonError) return sendOk(res, null, { error: bonError.message }, 500);

    // Jika bon terikat nota, hitung ulang total_amount nota
    const related = await deps.bonRepository.getRelatedRecords(req.supabase, req.params.id);
    for (const nota of related.notas) {
      const notaBons = await deps.notaRepository.getNotaBons(req.supabase, nota.id);
      const newTotal = notaBons.reduce((sum, b) => sum + Number(b.total || 0), 0);
      await req.supabase.from('notas').update({ total_amount: newTotal }).eq('id', nota.id);
    }

    const updated = await deps.bonRepository.getBon(req.supabase, req.params.id);
    sendOk(res, { recalculated: { pph, uang_minum, total, spsi_amount }, nota_total_updated: related.notas.length > 0, bon: updated });
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

  router.get('/notas/search/by-recipient', asyncHandler(async (req, res) => {
    const recipientName = String(req.query.recipient_name || req.query.q || '').trim();
    if (!recipientName) {
      throw apiError(400, 'RECIPIENT_NAME_REQUIRED', 'recipient_name wajib diisi.');
    }

    const filters = {
      start: req.query.start,
      end: req.query.end,
      status: req.query.status
    };
    const notas = await deps.notaRepository.searchNotasByRecipient(req.supabase, recipientName, filters);
    sendOk(res, notas, { count: notas.length, recipient_name: recipientName });
  }));

  router.post('/notas/pdf/from-bons', asyncHandler(async (req, res) => {
    const { bonIds } = await resolveBonIds(req, deps);
    const nota = await deps.notaRepository.createNota(req.supabase, req.body, bonIds);
    const bons = await deps.notaRepository.getNotaBons(req.supabase, nota.id);
    const isThermal = bons.length === 1;
    const buffer = isThermal
      ? await deps.generateThermalNotaPdf(nota, bons[0])
      : await deps.generateNotaPdf(nota, bons);

    sendPdf(res, buffer, `${nota.invoice_number}${isThermal ? '-thermal' : ''}.pdf`, {
      'X-Nota-Id': nota.id,
      'X-Invoice-Number': nota.invoice_number,
      'X-Pdf-Format': isThermal ? 'thermal' : 'a4'
    });
  }));

  router.get('/notas/send/:id/:whatsapp_id', asyncHandler(async (req, res) => {
    const [nota, bons] = await Promise.all([
      deps.notaRepository.getNota(req.supabase, req.params.id),
      deps.notaRepository.getNotaBons(req.supabase, req.params.id)
    ]);
    if (!nota) return sendOk(res, null, { error: 'Nota tidak ditemukan' }, 404);

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
      return sendOk(res, null, { error: 'Gagal kirim WA', detail: body }, 500);
    }

    sendOk(res, { message: 'WA terkirim', chatId });
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
      end: req.query.end,
      factory_id: req.query.factory_id || null
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
