const { generateNotaPdf, generateThermalNotaPdf } = require('../src/services/pdfService');

describe('pdfService', () => {
  it('generates a valid A4 nota PDF for many bons', async () => {
    const nota = {
      invoice_number: 'NOTA-TEST-001',
      invoice_date: '2026-05-16',
      recipient_name: 'PT SAWIT MAKMUR SEJAHTERA DENGAN NAMA YANG PANJANG',
      recipient_address: 'JALAN BESAR PERKEBUNAN SAWIT BLOK A NOMOR 123 KECAMATAN SECANGGANG KABUPATEN LANGKAT SUMATERA UTARA',
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

  it('generates a valid 57mm thermal nota PDF for a single bon', async () => {
    const nota = {
      invoice_number: 'NOTA-THERMAL-001',
      invoice_date: '2026-05-27T10:15:00.000Z',
      created_at: '2026-05-27T10:15:00.000Z',
      recipient_name: 'PT SAWIT MAKMUR',
      total_amount: 20_843_875
    };

    const bon = {
      netto_1: 9000,
      netto_2: 8500,
      price: 2500,
      dp: 100000,
      biaya_bongkar: 12,
      bp_colt: 100000,
      pph: 53125,
      uang_minum: 20000,
      bon_deductions: [{ label: 'POTONGAN', amount: 25000 }]
    };

    const buffer = await generateThermalNotaPdf(nota, bon);

    expect(buffer.subarray(0, 4).toString()).toBe('%PDF');
    expect(buffer.length).toBeGreaterThan(1000);
  });
});
