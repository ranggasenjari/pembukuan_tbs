process.env.PRINT_SERVER_URL = 'http://printer.test:7654';
process.env.PRINT_TOKEN = 'test-token';

const { printCetakan, fetchPrintStatus, PrintServerError } = require('../src/services/printService');

function makeSupabase(pdfBuffer = Buffer.from('%PDF-test')) {
  return {
    storage: {
      from() {
        return {
          async download() {
            return { data: new Blob([pdfBuffer], { type: 'application/pdf' }), error: null };
          }
        };
      }
    }
  };
}

function mockFetch(impl) {
  global.fetch = vi.fn(impl);
  vi.stubGlobal('fetch', global.fetch);
}

describe('printService', () => {
  afterEach(() => {
    vi.unstubAllGlobals();
  });

  describe('printCetakan', () => {
    it('downloads the PDF and sends multipart to the print server with token', async () => {
      const supabase = makeSupabase();
      mockFetch(async (url, options) => {
        expect(String(url)).toBe('http://printer.test:7654/api/print');
        expect(options.method).toBe('POST');
        expect(options.headers['X-Print-Token']).toBe('test-token');
        expect(options.body).toBeInstanceOf(FormData);
        expect(options.body.get('copies')).toBe('1');
        expect(options.body.get('print_size')).toBe('folio');
        expect(options.body.get('color_mode')).toBe('color');
        expect(options.body.get('fit_to_page')).toBe('true');
        const file = options.body.get('file');
        expect(file.name).toBe('cetakan-harian-2026-08-18-test.pdf');
        expect(file.type).toBe('application/pdf');
        return new Response(
          JSON.stringify({ ok: true, job: { request_id: 'Epson_L3210-9', paper_label: 'Folio / Legal penuh' } }),
          { status: 200, headers: { 'Content-Type': 'application/json' } }
        );
      });

      const result = await printCetakan({
        supabase,
        filePath: 'harian/f1/2026-08-18.pdf',
        title: 'Cetakan Harian 2026-08-18 - Test'
      });

      expect(result).toMatchObject({
        ok: true,
        requestId: 'Epson_L3210-9',
        paperLabel: 'Folio / Legal penuh'
      });
    });

    it('throws PrintServerError on 401 unauthorized', async () => {
      mockFetch(async () => new Response(JSON.stringify({ ok: false, error: 'Unauthorized' }), { status: 401 }));

      await expect(
        printCetakan({ supabase: makeSupabase(), filePath: 'harian/f1/2026-08-18.pdf', title: 'Test' })
      ).rejects.toMatchObject({ statusCode: 401 });
    });

    it('throws PrintServerError when the print server is unreachable', async () => {
      mockFetch(() => { throw new TypeError('fetch failed'); });

      await expect(
        printCetakan({ supabase: makeSupabase(), filePath: 'harian/f1/2026-08-18.pdf', title: 'Test' })
      ).rejects.toBeInstanceOf(PrintServerError);
    });
  });

  describe('fetchPrintStatus', () => {
    it('parses lpstat and active jobs from the status endpoint', async () => {
      mockFetch(async (url) => {
        expect(String(url)).toBe('http://printer.test:7654/api/status');
        return new Response(
          JSON.stringify({
            ok: true,
            printer: 'Epson_L3210',
            lpstat: { ok: true, stdout: 'printer Epson_L3210 is idle. enabled\nscheduler is running' },
            active_jobs: { ok: true, stdout: '' },
            completed_jobs: { ok: true, stdout: 'Epson_L3210-8 root 1024' }
          }),
          { status: 200, headers: { 'Content-Type': 'application/json' } }
        );
      });

      const status = await fetchPrintStatus();
      expect(status.printer).toBe('Epson_L3210');
      expect(status.lpstat).toContain('is idle');
      expect(status.activeJobs).toBe('');
      expect(status.completedJobs).toContain('Epson_L3210-8');
      expect(status.updatedAt).toBeTruthy();
    });

    it('throws PrintServerError when token is rejected', async () => {
      mockFetch(async () => new Response(JSON.stringify({ ok: false, error: 'Unauthorized' }), { status: 401 }));

      await expect(fetchPrintStatus()).rejects.toMatchObject({ statusCode: 401 });
    });
  });
});