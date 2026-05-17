function apiError(status, code, message, details) {
  const error = new Error(message);
  error.status = status;
  error.code = code;
  if (details !== undefined) error.details = details;
  return error;
}

function sendOk(res, data, meta, status = 200) {
  const body = { ok: true, data };
  if (meta !== undefined) body.meta = meta;
  return res.status(status).json(body);
}

function inferStatus(error) {
  if (error.status) return error.status;
  if (error.code === 'PGRST116') return 404;
  if (/duplicate|duplikat|konflik|conflict/i.test(error.message || '')) return 409;
  if (/tidak ditemukan|not found/i.test(error.message || '')) return 404;
  if (/wajib|pilih|minimal|harus|tidak dapat|melebihi|mencukupi|sudah|status/i.test(error.message || '')) {
    return 400;
  }
  return 500;
}

function inferCode(status, error) {
  if (error.code && typeof error.code === 'string' && !/^PGRST/.test(error.code)) {
    return error.code;
  }

  if (status === 400) return 'BAD_REQUEST';
  if (status === 401) return 'UNAUTHORIZED';
  if (status === 403) return 'FORBIDDEN';
  if (status === 404) return 'NOT_FOUND';
  if (status === 409) return 'CONFLICT';
  if (status === 503) return 'SERVICE_UNAVAILABLE';
  return 'INTERNAL_ERROR';
}

function apiErrorHandler(error, req, res, next) {
  const status = inferStatus(error);
  const code = inferCode(status, error);
  const message = status >= 500 && !error.expose
    ? 'Terjadi kesalahan server.'
    : (error.message || 'Terjadi kesalahan.');

  if (status >= 500) console.error(error);

  return res.status(status).json({
    ok: false,
    error: {
      code,
      message,
      ...(error.details !== undefined ? { details: error.details } : {})
    }
  });
}

function apiNotFound(req, res) {
  return res.status(404).json({
    ok: false,
    error: {
      code: 'NOT_FOUND',
      message: 'Endpoint API tidak ditemukan.'
    }
  });
}

module.exports = { apiError, apiErrorHandler, apiNotFound, sendOk };
