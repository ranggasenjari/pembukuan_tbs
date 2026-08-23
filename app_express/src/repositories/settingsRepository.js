const { env } = require('../config/env');
const { assertNoError } = require('./base');

const OCR_SETTING_KEY = 'ocr';
const OCR_MODES = {
  WEBHOOK: 'webhook',
  INTERNAL: 'internal'
};

const DEFAULT_MISTRAL_SCHEMA = {
  type: 'json_schema',
  json_schema: {
    name: 'slip_timbangan',
    strict: true,
    schema: {
      type: 'object',
      additionalProperties: false,
      properties: {
        factory_name: { type: ['string', 'null'] },
        ticket_number: { type: ['string', 'null'] },
        bon_date: { type: ['string', 'null'] },
        plate_number: { type: ['string', 'null'] },
        relation_name: { type: ['string', 'null'] },
        produk: { type: ['string', 'null'] },
        driver_name: { type: ['string', 'null'] },
        fruit_origin: { type: ['string', 'null'] },
        netto_1: { type: ['integer', 'null'] },
        netto_2: { type: ['integer', 'null'] },
        is_super: { type: ['boolean', 'null'] }
      },
      required: [
        'factory_name',
        'ticket_number',
        'bon_date',
        'plate_number',
        'relation_name',
        'produk',
        'driver_name',
        'fruit_origin',
        'netto_1',
        'netto_2',
        'is_super'
      ]
    }
  }
};

const DEFAULT_MISTRAL_PROMPT = `You are a document parsing assistant. Extract structured data from the OCR text.

Return JSON only. Format date as YYYY-MM-DD. Format number fields as integers with no punctuation.`;

function defaultOcrSettings() {
  return {
    mode: OCR_MODES.WEBHOOK,
    webhook_url: env.ocrWebhookUrl,
    webhook_key: '',
    mistral_api_key: '',
    mistral_prompt: DEFAULT_MISTRAL_PROMPT,
    mistral_output_schema: JSON.stringify(DEFAULT_MISTRAL_SCHEMA, null, 2),
    factory_settings: {}
  };
}

function normalizeFactorySettings(value) {
  const map = {};
  if (Array.isArray(value)) {
    value.forEach((raw) => {
      if (!raw || typeof raw !== 'object') return;
      const id = raw.factory_id || raw.id;
      if (!id) return;
      map[id] = {
        factory_id: id,
        factory_name: raw.factory_name || null,
        prompt: typeof raw.prompt === 'string' ? raw.prompt : (raw.prompt ? JSON.stringify(raw.prompt) : null),
        output_schema: typeof raw.output_schema === 'string'
          ? raw.output_schema
          : (raw.output_schema ? JSON.stringify(raw.output_schema, null, 2) : null)
      };
    });
  } else if (value && typeof value === 'object') {
    Object.entries(value).forEach(([key, raw]) => {
      if (!raw || typeof raw !== 'object') return;
      const id = raw.factory_id || raw.id || key;
      if (!id) return;
      map[id] = {
        factory_id: id,
        factory_name: raw.factory_name || null,
        prompt: typeof raw.prompt === 'string' ? raw.prompt : (raw.prompt ? JSON.stringify(raw.prompt) : null),
        output_schema: typeof raw.output_schema === 'string'
          ? raw.output_schema
          : (raw.output_schema ? JSON.stringify(raw.output_schema, null, 2) : null)
      };
    });
  }
  return map;
}

function normalizeOcrSettings(value = {}) {
  const defaults = defaultOcrSettings();
  return {
    ...defaults,
    ...value,
    mode: value.mode === OCR_MODES.INTERNAL ? OCR_MODES.INTERNAL : OCR_MODES.WEBHOOK,
    webhook_url: value.webhook_url || defaults.webhook_url,
    mistral_prompt: value.mistral_prompt || defaults.mistral_prompt,
    mistral_output_schema: typeof value.mistral_output_schema === 'string'
      ? value.mistral_output_schema
      : JSON.stringify(value.mistral_output_schema || DEFAULT_MISTRAL_SCHEMA, null, 2),
    factory_settings: normalizeFactorySettings(value.factory_settings)
  };
}

function isMissingSettingsTable(error) {
  return error && ['42P01', 'PGRST205', 'PGRST202'].includes(error.code);
}

async function getOcrSettings(supabase) {
  const result = await supabase
    .from('app_settings')
    .select('value')
    .eq('key', OCR_SETTING_KEY)
    .maybeSingle();

  if (result.error) {
    if (isMissingSettingsTable(result.error)) return defaultOcrSettings();
    throw result.error;
  }

  return normalizeOcrSettings(result.data?.value || {});
}

function parseFormFactorySettings(body, current = defaultOcrSettings()) {
  const existing = current.factory_settings || {};
  const map = { ...existing };
  const rawMap = body.factory_settings;

  if (rawMap && typeof rawMap === 'object') {
    Object.entries(rawMap).forEach(([key, raw]) => {
      if (!raw || typeof raw !== 'object') return;
      const id = raw.factory_id || key;
      if (!id) return;
      const prompt = String(raw.prompt || '').trim();
      const outputSchema = String(raw.output_schema || '').trim();
      if (prompt || outputSchema || raw.remove) {
        if (raw.remove) {
          delete map[id];
          return;
        }
        if (prompt || outputSchema) {
          map[id] = {
            factory_id: id,
            factory_name: raw.factory_name || map[id]?.factory_name || null,
            prompt: prompt || null,
            output_schema: outputSchema || null
          };
        }
      }
    });
  }

  // Hapus entri yang ditandai remove di dalam list (checkbox-posted array)
  const removed = Array.isArray(body.factory_settings_remove) ? body.factory_settings_remove : [];
  removed.forEach((id) => { if (id) delete map[id]; });

  return map;
}

function settingsFromBody(body, current = defaultOcrSettings()) {
  const next = {
    mode: body.mode === OCR_MODES.INTERNAL ? OCR_MODES.INTERNAL : OCR_MODES.WEBHOOK,
    webhook_url: String(body.webhook_url || '').trim(),
    webhook_key: String(body.webhook_key || '').trim() || current.webhook_key || '',
    mistral_api_key: String(body.mistral_api_key || '').trim() || current.mistral_api_key || '',
    mistral_prompt: String(body.mistral_prompt || '').trim(),
    mistral_output_schema: String(body.mistral_output_schema || '').trim(),
    factory_settings: parseFormFactorySettings(body, current)
  };

  return normalizeOcrSettings(next);
}

async function saveOcrSettings(supabase, settings) {
  const value = normalizeOcrSettings(settings);
  return assertNoError(await supabase
    .from('app_settings')
    .upsert({ key: OCR_SETTING_KEY, value }, { onConflict: 'key' })
    .select()
    .single());
}

module.exports = {
  DEFAULT_MISTRAL_SCHEMA,
  OCR_MODES,
  defaultOcrSettings,
  getOcrSettings,
  normalizeFactorySettings,
  normalizeOcrSettings,
  parseFormFactorySettings,
  saveOcrSettings,
  settingsFromBody
};
