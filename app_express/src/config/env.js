const path = require('path');
const dotenv = require('dotenv');
const { normalizeBasePath } = require('../services/url');

dotenv.config({ path: path.resolve(process.cwd(), '.env'), quiet: true });

function parseJsonObject(value, fallback) {
  if (!value) return fallback;
  try { const parsed = JSON.parse(value); return parsed && typeof parsed === 'object' && !Array.isArray(parsed) ? parsed : fallback; } catch { return fallback; }
}

function parseJsonArray(value, fallback) {
  if (!value) return fallback;
  try { const parsed = JSON.parse(value); return Array.isArray(parsed) ? parsed : fallback; } catch { return fallback; }
}

const DEFAULT_OCR_CHAT_TARGETS = {
  '120363427788590067@g.us': '120363402074969776@g.us',
  '120363408992040711@g.us': '120363429583334201@g.us',
  '120363410335724315@g.us': '120363430597655290@g.us'
};

const DEFAULT_OCR_DIRECT_TARGETS = [
  '120363402074969776@g.us',
  '120363429583334201@g.us',
  '120363430597655290@g.us'
];

const env = {
  nodeEnv: process.env.NODE_ENV || 'development',
  port: Number(process.env.PORT || 3000),
  sessionSecret: process.env.SESSION_SECRET || 'dev-session-secret',
  supabaseUrl: process.env.SUPABASE_URL || '',
  supabaseAnonKey: process.env.SUPABASE_ANON_KEY || process.env.SUPABASE_KEY || '',
  supabaseServiceRoleKey: process.env.SUPABASE_SERVICE_ROLE_KEY || process.env.SUPABASE_SERVICE_KEY || '',
  supabaseSchema: process.env.SUPABASE_SCHEMA || 'inv',
  externalApiKey: process.env.EXTERNAL_API_KEY || '',
  supabaseApiUserEmail: process.env.SUPABASE_API_USER_EMAIL || '',
  supabaseApiUserPassword: process.env.SUPABASE_API_USER_PASSWORD || '',
  basePath: normalizeBasePath(process.env.BASE_PATH || process.env.APP_BASE_PATH || ''),
  ocrWebhookUrl: process.env.OCR_WEBHOOK_URL || 'https://n8n.langkatkab.go.id/webhook/bon',
  maxUploadMb: Number(process.env.MAX_UPLOAD_MB || 10),
  printServerUrl: process.env.PRINT_SERVER_URL || 'http://103.167.236.90:7654',
  printToken: process.env.PRINT_TOKEN || '',
  wahaApiKey: process.env.WAHA_API_KEY || 'key_uchDI718apm4ceHSLZIFBPSd6X6qQuud',
  wahaBaseUrl: process.env.WAHA_BASE_URL || 'http://pflkt.langkatkab.go.id:3330',
  wahaSession: process.env.WAHA_SESSION || 'stj',
  ocrChatTargets: parseJsonObject(process.env.OCR_CHAT_TARGETS, DEFAULT_OCR_CHAT_TARGETS),
  ocrDirectTargets: parseJsonArray(process.env.OCR_DIRECT_TARGETS, DEFAULT_OCR_DIRECT_TARGETS)
};

function assertRuntimeEnv() {
  const missing = [];
  if (!env.supabaseUrl) missing.push('SUPABASE_URL');
  if (!env.supabaseAnonKey) missing.push('SUPABASE_ANON_KEY');
  if (!env.sessionSecret || env.sessionSecret === 'dev-session-secret') {
    if (env.nodeEnv === 'production') missing.push('SESSION_SECRET');
  }
  if (missing.length > 0) {
    throw new Error(`Missing required environment variables: ${missing.join(', ')}`);
  }
}

module.exports = { env, assertRuntimeEnv };
