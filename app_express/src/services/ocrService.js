const { env } = require('../config/env');
const { createServiceClient } = require('../config/supabase');
const settingsRepository = require('../repositories/settingsRepository');
const { uploadStorageFile } = require('./uploadService');

const MISTRAL_OCR_URL = 'https://api.mistral.ai/v1/ocr';

function unwrapWebhookPayload(payload) {
  if (Array.isArray(payload)) return payload[0] || {};
  return payload || {};
}

function parseJsonValue(value, fieldName) {
  if (!value) throw new Error(`${fieldName} wajib diisi.`);
  if (typeof value === 'object') return value;
  try {
    return JSON.parse(value);
  } catch (error) {
    throw new Error(`${fieldName} harus berupa JSON valid.`);
  }
}

function parseDocumentAnnotation(value) {
  if (!value) return {};
  if (typeof value === 'object') return value;
  try {
    return JSON.parse(value);
  } catch (error) {
    throw new Error('document_annotation dari Mistral bukan JSON valid.');
  }
}

function normalizeNumber(value) {
  if (value === null || value === undefined || value === '') return null;
  const number = Number(String(value).replace(/[^\d-]/g, ''));
  return Number.isFinite(number) ? number : null;
}

function normalizeOcrData(data = {}) {
  const annotation = parseDocumentAnnotation(data.document_annotation) || data;
  const normalized = {
    ...annotation,
    ticket_number: annotation.ticket_number ?? null,
    bon_date: annotation.bon_date ? String(annotation.bon_date).slice(0, 10) : null,
    plate_number: annotation.plate_number ? String(annotation.plate_number).replace(/[^a-zA-Z0-9]/g, '').toUpperCase() : null,
    driver_name: annotation.driver_name ?? null,
    relation_name: annotation.relation_name ?? null,
    factory_name: annotation.factory_name ?? null,
    fruit_origin: annotation.fruit_origin ?? null,
    netto_1: normalizeNumber(annotation.netto_1),
    netto_2: normalizeNumber(annotation.netto_2),
    notes: annotation.notes ?? annotation.catatan ?? null
  };

  if (annotation.is_super !== undefined) normalized.is_super = annotation.is_super;
  if (annotation.produk !== undefined) normalized.produk = annotation.produk;
  return normalized;
}

async function processWebhookOcr(file, settings, deps = {}) {
  const formData = new FormData();
  const blob = new Blob([file.buffer], { type: file.mimetype || 'image/jpeg' });
  formData.append('file', blob, file.originalname || 'bon.jpg');

  const headers = {};
  if (settings.webhook_key) headers['x-api-key'] = settings.webhook_key;

  const response = await (deps.fetch || fetch)(settings.webhook_url || env.ocrWebhookUrl, {
    method: 'POST',
    headers,
    body: formData
  });

  if (!response.ok) {
    throw new Error(`OCR gagal dengan status ${response.status}`);
  }

  const payload = await response.json();
  const data = unwrapWebhookPayload(payload);
  return {
    data,
    image_path: data.path || null,
    image_url: null,
    mode: 'webhook'
  };
}

async function processInternalOcr(file, settings, deps = {}) {
  if (!settings.mistral_api_key) throw new Error('Mistral API Key wajib diisi di Setting OCR.');
  if (!settings.mistral_prompt) throw new Error('Prompt Mistral wajib diisi di Setting OCR.');

  const schema = parseJsonValue(settings.mistral_output_schema, 'Output JSON schema');
  const body = {
    model: 'mistral-ocr-latest',
    document: {
      type: 'image_url',
      image_url: {
        url: `data:${file.mimetype || 'image/jpeg'};base64,${file.buffer.toString('base64')}`
      }
    },
    document_annotation_prompt: settings.mistral_prompt,
    document_annotation_format: schema
  };

  const response = await (deps.fetch || fetch)(MISTRAL_OCR_URL, {
    method: 'POST',
    headers: {
      Authorization: `Bearer ${settings.mistral_api_key}`,
      'Content-Type': 'application/json'
    },
    body: JSON.stringify(body)
  });

  if (!response.ok) {
    const detail = await response.text().catch(() => '');
    throw new Error(`Internal OCR gagal dengan status ${response.status}${detail ? `: ${detail}` : ''}`);
  }

  const payload = await response.json();
  const data = normalizeOcrData({
    ...payload,
    document_annotation: payload.document_annotation
  });

  const storageClient = deps.storageClient || createServiceClient() || deps.supabase;
  if (!storageClient) {
    throw new Error('Supabase service role key wajib diisi untuk upload gambar Internal OCR.');
  }

  const upload = await uploadStorageFile(storageClient, 'receipts', 'bons', file, { upsert: true });
  return {
    data,
    image_path: upload?.path || null,
    image_url: upload?.publicUrl || null,
    mode: 'internal'
  };
}

async function processBonOcr(file, options = {}) {
  if (!file) throw new Error('File gambar wajib diupload.');

  const settings = options.settings || await settingsRepository.getOcrSettings(options.supabase);
  if (settings.mode === settingsRepository.OCR_MODES.INTERNAL) {
    return processInternalOcr(file, settings, options);
  }
  return processWebhookOcr(file, settings, options);
}

module.exports = {
  MISTRAL_OCR_URL,
  normalizeOcrData,
  processBonOcr,
  processInternalOcr,
  processWebhookOcr
};
