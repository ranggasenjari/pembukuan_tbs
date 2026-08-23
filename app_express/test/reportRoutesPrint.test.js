const express = require('express');
const request = require('supertest');

const reportRoutes = require('../src/routes/reportRoutes');

function makeSupabase(record) {
  return {
    storage: {
      from() {
        return {
          async download() {
            return { data: new Blob([Buffer.from('%PDF-test')], { type: 'application/pdf' }), error: null };
          }
        };
      }
    },
    from(table) {
      if (table === 'cetakan_history') {
        return {
          select() { return this; },
          eq() { return this; },
          order() { return this; },
          async single() { return { data: record, error: null }; },
          async maybeSingle() { return { data: record, error: null }; }
        };
      }
      if (table === 'factories') {
        return {
          select() { return this; },
          eq() { return this; },
          async maybeSingle() { return { data: { name: 'PT PABRIK A' }, error: null }; }
        };
      }
      return {
        select() { return this; },
        eq() { return this; },
        async maybeSingle() { return { data: null, error: null }; },
        async single() { return { data: null, error: null }; }
      };
    }
  };
}

function makeApp(supabase) {
  const app = express();
  app.use(express.json());
  app.use(express.urlencoded({ extended: true }));
  app.use((req, res, next) => {
    req.supabase = supabase;
    req.flash = vi.fn();
    res.locals.url = (target) => target;
    next();
  });
  app.use('/reports', reportRoutes);
  app.use((error, req, res, next) => {
    res.status(500).json({ error: error.message });
  });
  return app;
}

const record = {
  id: 'c1',
  date: '2026-08-18',
  factory_id: 'f1',
  file_path: 'harian/f1/2026-08-18.pdf'
};

describe('reportRoutes print', () => {
  afterEach(() => {
    vi.unstubAllGlobals();
  });

  it('POST /reports/harian/:id/print sends the stored PDF and returns the job', async () => {
    global.fetch = vi.fn(async (url, options) => {
      expect(String(url)).toMatch(/\/api\/print$/);
      expect(options.method).toBe('POST');
      expect(options.body).toBeInstanceOf(FormData);
      return new Response(
        JSON.stringify({ ok: true, job: { request_id: 'Epson_L3210-9', paper_label: 'Folio / Legal penuh' } }),
        { status: 200, headers: { 'Content-Type': 'application/json' } }
      );
    });

    const response = await request(makeApp(makeSupabase(record)))
      .post('/reports/harian/c1/print');

    expect(response.status).toBe(200);
    expect(response.body).toMatchObject({
      ok: true,
      requestId: 'Epson_L3210-9',
      paperLabel: 'Folio / Legal penuh'
    });
    expect(global.fetch).toHaveBeenCalledTimes(1);
  });

  it('returns 502 with error message when the print server is unreachable', async () => {
    global.fetch = vi.fn(() => { throw new TypeError('fetch failed'); });

    const response = await request(makeApp(makeSupabase(record)))
      .post('/reports/harian/c1/print');

    expect(response.status).toBe(502);
    expect(response.body).toMatchObject({ ok: false, error: expect.stringContaining('fetch failed') });
  });

  it('GET /reports/harian/:id/print-status returns printer status', async () => {
    global.fetch = vi.fn(async (url) => {
      expect(String(url)).toMatch(/\/api\/status$/);
      return new Response(
        JSON.stringify({
          ok: true,
          printer: 'Epson_L3210',
          lpstat: { ok: true, stdout: 'printer Epson_L3210 is idle. enabled' },
          active_jobs: { ok: true, stdout: '' },
          completed_jobs: { ok: true, stdout: 'Epson_L3210-8 root 1024' }
        }),
        { status: 200, headers: { 'Content-Type': 'application/json' } }
      );
    });

    const response = await request(makeApp(makeSupabase(record)))
      .get('/reports/harian/c1/print-status');

    expect(response.status).toBe(200);
    expect(response.body.ok).toBe(true);
    expect(response.body.status.printer).toBe('Epson_L3210');
    expect(response.body.status.lpstat).toContain('is idle');
  });

  it('returns 401 error when status polling is unauthorized', async () => {
    global.fetch = vi.fn(async () => new Response(JSON.stringify({ ok: false, error: 'Unauthorized' }), { status: 401 }));

    const response = await request(makeApp(makeSupabase(record)))
      .get('/reports/harian/c1/print-status');

    expect(response.status).toBe(401);
    expect(response.body.ok).toBe(false);
  });
});