const { buildDescription } = require('../src/services/realtimeService');

describe('realtimeService buildDescription', () => {
  it('describes bon changes with plate/ticket', () => {
    expect(buildDescription('bons', 'UPDATE', { plate_number: 'BK 1234 AA' }, {})).toBe('Bon BK 1234 AA diubah');
    expect(buildDescription('bons', 'INSERT', { ticket_number: 'TKT-1', plate_number: null }, {})).toBe('Bon TKT-1 ditambahkan');
    expect(buildDescription('bons', 'DELETE', null, { plate_number: 'BK 5678 CD' })).toBe('Bon BK 5678 CD dihapus');
  });

  it('describes nota and payment changes', () => {
    expect(buildDescription('notas', 'INSERT', { invoice_number: 'NOTA-123' }, {})).toBe('Nota NOTA-123 ditambahkan');
    const payment = buildDescription('payments', 'INSERT', { amount_paid: 1500000 }, {});
    expect(payment.replace(/\u00A0/g, ' ')).toBe('Pembayaran Rp 1.500.000 ditambahkan');
  });

  it('uses name for relation/factory and falls back gracefully', () => {
    expect(buildDescription('relation_agents', 'UPDATE', { name: 'AGEN MAJU' }, {})).toBe('Relasi/Agen AGEN MAJU diubah');
    expect(buildDescription('vehicles', 'UPDATE', {}, {})).toBe('Kendaraan diubah');
  });
});
