const { calculateBon, parseDeductions } = require('../src/services/calculations');

describe('bon calculations', () => {
  it('matches Flutter bon total formula', () => {
    const result = calculateBon({
      netto_1: 9000,
      netto_2: 8500,
      price: 2500,
      dp: 100000,
      biaya_bongkar: 12,
      bp_colt: 100000,
      pph: 0,
      uang_minum: '',
      deductions: [{ label: 'Rolling', amount: 50000 }]
    });

    expect(result.subtotal).toBe(21_250_000);
    expect(result.pph).toBe(0);
    expect(result.uang_minum).toBe(20_000);
    expect(result.total_biaya_bongkar).toBe(108_000);
    expect(result.total).toBe(20_872_000);
  });

  it('auto calculates pph when field is omitted', () => {
    const result = calculateBon({
      netto_1: 7000,
      netto_2: 7000,
      price: 2000,
      dp: 0,
      biaya_bongkar: 12,
      bp_colt: 100000,
      deductions: []
    });

    expect(result.pph).toBe(35_000);
    expect(result.uang_minum).toBe(10_000);
    expect(result.total).toBe(13_771_000);
  });

  it('calculates factory SPSI per kilogram snapshot', () => {
    const result = calculateBon({
      netto_1: 9000,
      netto_2: 8500,
      price: 2500,
      biaya_bongkar: 12,
      spsi_calculation_mode: 'PER_KG',
      spsi_rate: 15,
      bp_colt: 100000,
      pph: 0,
      uang_minum: 0,
      deductions: []
    });

    expect(result.spsi_rate).toBe(15);
    expect(result.spsi_amount).toBe(135000);
    expect(result.total_biaya_bongkar).toBe(135000);
  });

  it('calculates factory SPSI fixed snapshot', () => {
    const result = calculateBon({
      netto_1: 9000,
      netto_2: 8500,
      price: 2500,
      biaya_bongkar: 12,
      spsi_calculation_mode: 'FIX',
      spsi_rate: 50000,
      bp_colt: 100000,
      pph: 0,
      uang_minum: 0,
      deductions: []
    });

    expect(result.spsi_calculation_mode).toBe('FIX');
    expect(result.spsi_amount).toBe(50000);
    expect(result.total_biaya_bongkar).toBe(50000);
  });

  it('parses dynamic deduction arrays from form body', () => {
    const deductions = parseDeductions({
      deduction_label: ['BONGKAR EXTRA', '', 'LAIN'],
      deduction_amount: ['10000', '0', '25000']
    });

    expect(deductions).toEqual([
      { label: 'BONGKAR EXTRA', amount: 10000 },
      { label: 'LAIN', amount: 25000 }
    ]);
  });
});
