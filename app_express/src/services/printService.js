const { env } = require('../config/env');

class PrintServerError extends Error {
  constructor(message, statusCode) {
    super(message);
    this.name = 'PrintServerError';
    this.statusCode = statusCode;
  }
}

function printHeaders() {
  const headers = {};
  if (env.printToken) headers['X-Print-Token'] = env.printToken;
  return headers;
}

function errorMessage(statusCode, body) {
  if (statusCode === 401) return 'Token printer salah atau kosong.';
  if (statusCode === 404) return 'Endpoint printer tidak ditemukan di server.';
  if (statusCode === 413) return 'File terlalu besar untuk server printer.';
  if (statusCode === 502) return 'Perintah print gagal dijalankan di server printer.';
  if (statusCode >= 500) return 'Server printer mengalami kesalahan internal.';
  try {
    const decoded = JSON.parse(body);
    if (decoded?.error) return `Server printer menolak: ${decoded.error}`;
  } catch (_) {
    if (body && body.trim()) return `Server printer menolak request (${statusCode}): ${body.trim()}`;
  }
  return `Server printer menolak request (${statusCode}).`;
}

function commandStdout(payload, key) {
  if (payload && typeof payload === 'object' && typeof payload[key] === 'object') {
    return String(payload[key].stdout || '').trim();
  }
  return '';
}

async function requestJson(path, options = {}) {
  const url = `${env.printServerUrl.replace(/\/+$/, '')}${path}`;
  let response;
  try {
    response = await fetch(url, {
      ...options,
      headers: { ...printHeaders(), ...(options.headers || {}) },
      signal: AbortSignal.timeout(options.timeout || 30_000)
    });
  } catch (error) {
    if (error?.name === 'TimeoutError') {
      throw new PrintServerError('Timeout menghubungi server printer.', 0);
    }
    throw new PrintServerError(`Server printer tidak terhubung: ${error.message}`, 0);
  }

  const text = await response.text();
  let body = null;
  try {
    body = text ? JSON.parse(text) : null;
  } catch (_) {
    body = text;
  }

  if (response.status < 200 || response.status >= 300) {
    throw new PrintServerError(errorMessage(response.status, text), response.status);
  }
  return body;
}

async function downloadCetakanPdf(supabase, filePath) {
  const { data, error } = await supabase.storage.from('cetakan').download(filePath);
  if (error || !data) {
    throw new Error(`File PDF tidak bisa diambil dari penyimpanan: ${error?.message || 'tidak ditemukan'}`);
  }
  return Buffer.from(await data.arrayBuffer());
}

async function printCetakan({ supabase, filePath, title }) {
  const buffer = await downloadCetakanPdf(supabase, filePath);
  const safeName = String(title || 'cetakan')
    .replace(/[^a-z0-9]+/gi, '-')
    .replace(/^-+|-+$/g, '')
    .toLowerCase() || 'cetakan';

  const form = new FormData();
  form.append('file', new Blob([buffer], { type: 'application/pdf' }), `${safeName}.pdf`);
  form.append('copies', '1');
  form.append('print_size', 'folio');
  form.append('paper_preset', 'folio');
  form.append('color_mode', 'color');
  form.append('fit_to_page', 'true');
  form.append('title', String(title || safeName));

  const body = await requestJson('/api/print', {
    method: 'POST',
    body: form,
    timeout: 60_000
  });

  const job = body?.job;
  const requestId = job?.request_id || body?.job_id || null;
  const paperLabel = job?.paper_label || job?.print_size_label || null;
  if (!requestId) {
    throw new PrintServerError('Server printer menerima file tetapi tidak mengembalikan ID job.', 0);
  }

  return { requestId, paperLabel, job, ok: body?.ok !== false };
}

async function fetchPrintStatus() {
  const body = await requestJson('/api/status', { timeout: 10_000 });
  return {
    ok: body?.ok !== false,
    printer: body?.printer || '',
    lpstat: commandStdout(body, 'lpstat'),
    activeJobs: commandStdout(body, 'active_jobs'),
    completedJobs: commandStdout(body, 'completed_jobs'),
    updatedAt: new Date().toISOString()
  };
}

module.exports = {
  PrintServerError,
  printCetakan,
  fetchPrintStatus,
  downloadCetakanPdf
};
