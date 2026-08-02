const format = require('../src/services/format');

describe('contextual status labels', () => {
  it('labels bon status according to nota workflow context', () => {
    expect(format.bonStatusLabel('BELUM_DIBAYAR')).toBe('Belum Dibuat Nota');
    expect(format.bonStatusLabel('TERTAGIH')).toBe('Menunggu Pembayaran');
    expect(format.bonStatusLabel('LUNAS')).toBe('Lunas');
  });

  it('labels nota status according to payment context', () => {
    expect(format.notaStatusLabel('BELUM_DIBAYAR')).toBe('Belum Terbit / Data Lama');
    expect(format.notaStatusLabel('TERTAGIH')).toBe('Menunggu Pembayaran');
    expect(format.notaStatusLabel('LUNAS')).toBe('Lunas');
  });

  it('describes editable and payment waiting states', () => {
    expect(format.bonStatusDescription('BELUM_DIBAYAR')).toContain('belum masuk nota');
    expect(format.notaStatusDescription('TERTAGIH')).toContain('menunggu pembayaran');
  });
});
