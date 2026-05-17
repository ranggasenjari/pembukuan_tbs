const { generateNotaPdf } = require('../src/services/pdfService');

describe('pdfService', () => {
  it('generates a valid A4 nota PDF for many bons', async () => {
    const nota = {
      invoice_number: 'NOTA-TEST-001',
      invoice_date: '2026-05-16',
      recipient_name: 'PT SAWIT MAKMUR SEJAHTERA DENGAN NAMA YANG PANJANG',
      recipient_address: 'MEDAN, SUMATERA UTARA',
      total_amount: 0
    };

    const bons = Array.from({ length: 32 }, (_, index) => ({
      bon_date: '2026-05-16',
      ticket_number: `TICKET-${index + 1}`,
      plate_number: `BK ${1000 + index} XY`,
      driver_name: `DRIVER PANJANG ${index + 1}`,
      relation_name: 'RELASI TEST',
      netto_1: 9000 + index,
      netto_2: 8500 + index,
      price: 2500,
      dp: 100000,
      biaya_bongkar: 12,
      bp_colt: 100000,
      pph: 53125,
      uang_minum: 20000,
      total: 20800000 + index,
      bon_deductions: [{ label: 'POTONGAN TAMBAHAN TEST', amount: 25000 }]
    }));

    nota.total_amount = bons.reduce((sum, bon) => sum + bon.total, 0);
    const buffer = await generateNotaPdf(nota, bons);

    expect(buffer.subarray(0, 4).toString()).toBe('%PDF');
    expect(buffer.length).toBeGreaterThan(1000);
  });
});
