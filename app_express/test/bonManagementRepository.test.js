const { normalizePlate, summarize } = require('../src/repositories/bonManagementRepository');

describe('bonManagementRepository', () => {
  it('normalizes plate numbers for payment relation matching', () => {
    expect(normalizePlate(' BK 1234 ab ')).toBe('BK1234AB');
    expect(normalizePlate(null)).toBe('');
  });

  it('summarizes managed bon cards', () => {
    const summary = summarize([
      { status: 'BELUM_DIBAYAR', netto_2: 1000 },
      { status: 'TERTAGIH', netto_2: 2500 },
      { status: 'LUNAS', netto_2: 1500 }
    ]);

    expect(summary).toEqual({
      totalBons: 3,
      unbilledBons: 1,
      billedBons: 1,
      paidBons: 1,
      totalTonnage: 5
    });
  });
});
