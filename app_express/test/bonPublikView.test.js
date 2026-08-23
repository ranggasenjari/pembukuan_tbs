const express = require('express');
const request = require('supertest');
const path = require('path');

describe('bon publik view', () => {
  it('renders the public deck controls and public API endpoints', async () => {
    const app = express();
    app.set('view engine', 'ejs');
    app.set('views', path.join(__dirname, '..', 'src', 'views'));
    app.get('/', (req, res) => res.render('bon/publik', {
      title: 'Update Bon Hari Ini', today: '2026-08-22', basePath: '', factories: [{ id: 'factory-1', name: 'Pabrik A' }], relationAgents: [], paymentRelations: [],
      items: [{ bon: { id: 'bon-1', status: 'TERTAGIH', plate_number: 'BL 1 A', bon_deductions: [] }, nota: { id: 'nota-1' }, paymentRelation: { name: 'RELASI BAYAR A', contact: '0812', payment_relation_accounts: [{ bank_name: 'BCA', account_number: '123', account_name: 'BUDI' }] } }]
    }));

    const response = await request(app).get('/');
    expect(response.status).toBe(200);
    expect(response.text).toContain('Cari plat, relasi, atau driver');
    expect(response.text).toContain('Semua pabrik');
    expect(response.text).toContain('data-factory-id="factory-1"');
    expect(response.text).toContain('/api/bon/publik/${bon.id}');
    expect(response.text).toContain('Nota selesai');
    expect(response.text).toContain('payment-info');
    expect(response.text).toContain('copy-total');
    expect(response.text).toContain('copy-contact');
  });
});
