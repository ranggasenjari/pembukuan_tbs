const express = require('express');
const request = require('supertest');
const path = require('path');
const format = require('../src/services/format');

function makeApp(history) {
  const app = express();
  app.set('view engine', 'ejs');
  app.set('views', path.join(__dirname, '..', 'src', 'views'));

  app.use((req, res, next) => {
    res.locals.format = format;
    res.locals.basePath = '';
    res.locals.url = (target) => target;
    next();
  });
  app.get('/reports/harian', (req, res) => {
    res.render('reports/harian', { title: 'Cetakan', history });
  });
  app.use((error, req, res, next) => {
    res.status(500).json({ error: error.message, stack: error.stack });
  });
  return app;
}

describe('harian (Cetakan) view', () => {
  it('renders Print button and print status dialog for each record', async () => {
    const app = makeApp([
      {
        id: 'c1',
        date: '2026-08-18',
        printed_at: '2026-08-18T05:00:00Z',
        total_bons: 5,
        total_tonase: 12345,
        total_amount: 2500000,
        factories: { name: 'PT PABRIK A' }
      }
    ]);

    const response = await request(app).get('/reports/harian');

    expect(response.status).toBe(200);
    const html = response.text;
    expect(html).toContain(`/reports/harian/c1/print`);
    expect(html).toContain(`/reports/harian/c1/print-status`);
    expect(html).toContain('data-filename="cetakan-harian-2026-08-18-pt-pabrik-a.pdf"');
    expect(html).toContain('print-status-dialog');
    expect(html).toContain('confirm-print');
    expect(html).toContain('/js/cetak-print.js');
  });

  it('renders empty state when there is no history', async () => {
    const app = makeApp([]);
    const response = await request(app).get('/reports/harian');
    expect(response.status).toBe(200);
    expect(response.text).toContain('Belum ada cetakan harian tersimpan.');
  });
});