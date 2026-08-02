const path = require('path');
const dotenv = require('dotenv');
const { normalizeBasePath } = require('../services/url');

dotenv.config({ path: path.resolve(process.cwd(), '.env'), quiet: true });

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
  maxUploadMb: Number(process.env.MAX_UPLOAD_MB || 10)
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
