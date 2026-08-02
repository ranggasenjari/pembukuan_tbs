const { bonSpsiAmount, buildNotaWhatsappMessage } = require('../src/services/notaWhatsapp');

describe('notaWhatsapp', () => {
  it('uses SPSI snapshot with legacy fallback', () => {
    expect(bonSpsiAmount({ spsi_amount: 50000, biaya_bongkar: 12, netto_1: 9000 })).toBe(50000);
    expect(bonSpsiAmount({ biaya_bongkar: 12, netto_1: 9000 })).toBe(108000);
  });

  it('formats per-bon whatsapp message and final total', () => {
    const message = buildNotaWhatsappMessage(
      { invoice_number: 'NOTA-1', recipient_name: 'AGEN MAJU', total_amount: 1000000 },
      [{
        plate_number: 'BK 1234 AA',
        driver_name: 'BUDI',
        netto_2: 1000,
        price: 1200,
        spsi_amount: 10000,
        bp_colt: 5000,
        total: 1000000
      }]
    );

    expect(message).toContain('Relasi: AGEN MAJU');
    expect(message).toContain('1000 kg x Rp');
    expect(message).toContain('SPSI: Rp');
    expect(message).toContain('TOTAL NOTA: Rp');
  });

  it('adds DP/Panjar and Total Akhir when bon has DP', () => {
    const message = buildNotaWhatsappMessage(
      { invoice_number: 'NOTA-2', recipient_name: 'AGEN MAJU', total_amount: 800000 },
      [{
        plate_number: 'BK 1234 AA',
        driver_name: 'BUDI',
        netto_2: 1000,
        price: 1200,
        spsi_amount: 10000,
        bp_colt: 5000,
        dp: 200000,
        bon_deductions: [{ label: 'Pengiriman', amount: 10000 }],
        total: 800000
      }]
    );

    // Normalisasi non-breaking space (U+00A0) dari formatter id-ID
    const normalized = message.replace(/\u00A0/g, ' ');
    // Total bon ditampilkan sebelum DP
    expect(normalized).toContain('*Total bon: Rp 1.000.000*');
    expect(normalized).toContain('*TOTAL NOTA: Rp 1.000.000*');
    expect(normalized).toContain('DP / Panjar: Rp 200.000');
    expect(normalized).toContain('*Total Akhir: Rp 800.000*');
    expect(normalized).toContain('      Pengiriman: Rp 10.000');
    // DP tidak dicantumkan pada daftar potongan
    expect(normalized).not.toContain('      DP: Rp');
  });
});
