const express = require('express');
const request = require('supertest');
const { createApiV1Router } = require('../src/routes/apiV1Routes');

function makeApp(deps) {
  const app = express();
  app.use(express.json());
  app.use(express.urlencoded({ extended: true }));
  app.use('/api/v1', createApiV1Router({
    authMiddleware: [
      (req, res, next) => {
        req.supabase = {};
        next();
      }
    ],
    ...deps
  }));
  return app;
}

describe('apiV1Routes', () => {
  it('creates a bon through the external API', async () => {
    const bonRepository = {
      serializeBon: vi.fn((body, calculated, imageUrl) => ({
        ticket_number: body.ticket_number,
        total: calculated.total,
        image_url: imageUrl
      })),
      createBon: vi.fn(async (supabase, data, deductions) => ({
        id: 'bon-1',
        ...data,
        bon_deductions: deductions
      }))
    };

    const response = await request(makeApp({
      bonRepository,
      uploadPublicFile: vi.fn(async () => null)
    }))
      .post('/api/v1/bons')
      .send({
        ticket_number: 'BON-1',
        bon_date: '2026-05-16',
        plate_number: 'BK 1 XY',
        netto_1: 9000,
        netto_2: 8500,
        price: 2500,
        dp: 100000,
        biaya_bongkar: 12,
        bp_colt: 100000,
        deductions: [{ label: 'POTONGAN', amount: 25000 }]
      });

    expect(response.status).toBe(201);
    expect(response.body.ok).toBe(true);
    expect(response.body.data.total).toBe(20_843_875);
    expect(response.body.data.bon_deductions).toEqual([{ label: 'POTONGAN', amount: 25000 }]);
  });

  it('creates a nota from bon codes and returns A4 PDF', async () => {
    const nota = { id: 'nota-1', invoice_number: 'NOTA-1', total_amount: 1000 };
    const bon = { id: 'bon-1', ticket_number: 'BON-1', total: 1000 };
    const createNota = vi.fn(async () => nota);

    const response = await request(makeApp({
      resolveBonIdsByTicketNumbers: vi.fn(async () => ({ bonIds: ['bon-1'], bons: [bon] })),
      notaRepository: {
        createNota,
        getNotaBons: vi.fn(async () => [bon])
      },
      generateNotaPdf: vi.fn(async () => Buffer.from('%PDF mocked'))
    }))
      .post('/api/v1/notas/pdf/from-bons')
      .send({
        recipient_name: 'PT MAKMUR',
        bon_codes: ['BON-1']
      });

    expect(response.status).toBe(200);
    expect(response.headers['content-type']).toMatch(/application\/pdf/);
    expect(response.headers['x-nota-id']).toBe('nota-1');
    expect(createNota).toHaveBeenCalledWith({}, expect.objectContaining({ recipient_name: 'PT MAKMUR' }), ['bon-1']);
  });

  it('creates a payment only after proof upload is provided', async () => {
    const createPayment = vi.fn(async () => ({
      id: 'payment-1',
      invoice_id: 'nota-1',
      proof_url: 'https://example.test/proof.jpg'
    }));

    const response = await request(makeApp({
      uploadPublicFile: vi.fn(async () => 'https://example.test/proof.jpg'),
      paymentRepository: { createPayment }
    }))
      .post('/api/v1/payments')
      .field('invoice_id', 'nota-1')
      .field('amount_paid', '100000')
      .attach('proof', Buffer.from('proof'), 'proof.jpg');

    expect(response.status).toBe(201);
    expect(response.body.ok).toBe(true);
    expect(createPayment).toHaveBeenCalledWith({}, expect.objectContaining({ invoice_id: 'nota-1' }), 'https://example.test/proof.jpg');
  });
});
