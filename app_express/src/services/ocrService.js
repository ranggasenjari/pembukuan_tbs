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

// Mistral `document_annotation_format` mengharuskan bentuk
// { type: 'json_schema', json_schema: { name, strict, schema } }.
// Bila user menyimpan schema "dalam" (langsung { type: 'object', properties ... }),
// bungkus ulang supaya request valid. Bila sudah benar, biarkan.
function normalizeAnnotationFormat(value) {
  const parsed = parseJsonValue(value, 'Output JSON schema');
  if (!parsed || typeof parsed !== 'object') {
    throw new Error('Output JSON schema harus berupa object valid.');
  }
  if (parsed.type === 'json_schema' && parsed.json_schema && parsed.json_schema.schema) {
    return parsed;
  }
  if (parsed.type === 'text' || parsed.type === 'json_object') {
    return parsed;
  }
  // Schema "dalam" tanpa pembungkus → bungkus sebagai json_schema
  return {
    type: 'json_schema',
    json_schema: {
      name: parsed.name || 'slip_timbangan',
      strict: parsed.strict ?? true,
      schema: parsed.json_schema?.schema || parsed
    }
  };
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

async function processWebhookOcr(file, settings, deps = {}, factoryName = null) {
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
  if (factoryName && String(factoryName).trim()) data.factory_name = String(factoryName).trim();
  return {
    data,
    image_path: data.path || null,
    image_url: null,
    mode: 'webhook'
  };
}

async function processInternalOcr(file, settings, deps = {}, factorySettings = null, factoryName = null) {
  if (!settings.mistral_api_key) throw new Error('Mistral API Key wajib diisi di Setting OCR.');

  const prompt = (factorySettings && factorySettings.prompt && String(factorySettings.prompt).trim())
    ? String(factorySettings.prompt).trim()
    : settings.mistral_prompt;
  const schemaSource = (factorySettings && factorySettings.output_schema && String(factorySettings.output_schema).trim())
    ? String(factorySettings.output_schema).trim()
    : settings.mistral_output_schema;
  if (!prompt) throw new Error('Prompt Mistral wajib diisi di Setting OCR.');

  const schema = normalizeAnnotationFormat(schemaSource);
  const body = {
    model: 'mistral-ocr-latest',
    document: {
      type: 'image_url',
      image_url: {
        url: `data:${file.mimetype || 'image/jpeg'};base64,${file.buffer.toString('base64')}`
      }
    },
    document_annotation_prompt: prompt,
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
  if (factoryName && String(factoryName).trim()) data.factory_name = String(factoryName).trim();

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

function resolveFactoryOcrSettings(settings, factoryId) {
  if (!factoryId) return null;
  const factorySettings = settings?.factory_settings || {};
  return factorySettings[String(factoryId)] || null;
}

function resolveFactoryName(factories, factoryId, fallbackName) {
  if (fallbackName && String(fallbackName).trim()) return String(fallbackName).trim();
  const factory = (factories || []).find((item) => item.id === String(factoryId));
  return factory?.name || null;
}

async function processBonOcr(file, options = {}) {
  if (!file) throw new Error('File gambar wajib diupload.');

  const settings = options.settings || await settingsRepository.getOcrSettings(options.supabase);
  const factorySettings = resolveFactoryOcrSettings(settings, options.factory_id);
  const factoryName = resolveFactoryName(options.factories, options.factory_id, options.factory_name);
  if (settings.mode === settingsRepository.OCR_MODES.INTERNAL) {
    return processInternalOcr(file, settings, options, factorySettings, factoryName);
  }
  return processWebhookOcr(file, settings, options, factoryName);
}

module.exports = {
  MISTRAL_OCR_URL,
  normalizeAnnotationFormat,
  normalizeOcrData,
  processBonOcr,
  processInternalOcr,
  processWebhookOcr,
  resolveFactoryName,
  resolveFactoryOcrSettings
};
