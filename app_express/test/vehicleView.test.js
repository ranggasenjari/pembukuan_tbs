const express = require('express');
const request = require('supertest');
const path = require('path');
const format = require('../src/services/format');

function makeApp() {
  const app = express();
  app.set('view engine', 'ejs');
  app.set('views', path.join(__dirname, '..', 'src', 'views'));

  const vehicles = [{
    id: 'v1',
    plate_number: 'BL1234AB',
    driver_name: 'BUDI',
    potongan_bp: 100000,
    harga: 20,
    is_super: false,
    driver_list: ['BUDI'],
    relation_list: ['PT A'],
    factory_list: ['PT PABRIK'],
    payment_relation_id: 'r1',
    payment_relation_name: 'BANK BCA'
  }];
  const paymentRelations = [{ id: 'r1', name: 'BANK BCA' }, { id: 'r2', name: 'BANK MANDIRI' }];

  app.use((req, res, next) => {
    res.locals.format = format;
    res.locals.basePath = '';
    res.locals.url = (target) => target;
    next();
  });
  app.get('/vehicles', (req, res) => {
    res.render('vehicles/index', { title: 'Kendaraan', vehicles, paymentRelations, q: req.query.q || '' });
  });
  app.use((error, req, res, next) => {
    res.status(500).json({ error: error.message, stack: error.stack });
  });
  return app;
}

describe('vehicles index view', () => {
  it('renders search filter, inline form, BP pills, harga, and relasi bayar select', async () => {
    const app = makeApp();
    const response = await request(app).get('/vehicles');
    expect(response.status).toBe(200);
    const html = response.text;
    expect(html).toContain('Cari plat nomor');
    expect(html).toContain('BL1234AB');
    expect(html).toContain('BANK BCA');
    expect(html).toContain('value="150000"');
    expect(html).toContain('payment_relation_id');
    expect(html).toContain('rel-bayar-dialog');
    expect(html).toContain('data-vehicle-id=');
  });
});