const crypto = require('crypto');
const { env } = require('../config/env');
const { apiError } = require('../services/apiResponse');
const { getSystemSupabaseClient } = require('../services/systemSupabase');

function hash(value) {
  return crypto.createHash('sha256').update(String(value || '')).digest();
}

function isValidApiKey(provided, expected) {
  if (!provided || !expected) return false;
  return crypto.timingSafeEqual(hash(provided), hash(expected));
}

function requireExternalApiKey(req, res, next) {
  if (!env.externalApiKey) {
    return next(apiError(503, 'API_KEY_NOT_CONFIGURED', 'EXTERNAL_API_KEY belum dikonfigurasi.'));
  }

  const provided = req.get('x-api-key');
  if (!isValidApiKey(provided, env.externalApiKey)) {
    return next(apiError(401, 'UNAUTHORIZED', 'API key tidak valid.'));
  }

  return next();
}

async function attachSystemSupabase(req, res, next) {
  try {
    req.supabase = await getSystemSupabaseClient();
    return next();
  } catch (error) {
    return next(error);
  }
}

module.exports = { attachSystemSupabase, isValidApiKey, requireExternalApiKey };
