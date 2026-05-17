const PAYMENT_STATUS = {
  BELUM_DIBAYAR: 'BELUM_DIBAYAR',
  TERTAGIH: 'TERTAGIH',
  LUNAS: 'LUNAS'
};

function toNumber(value, fallback = 0) {
  if (value === null || value === undefined || value === '') return fallback;
  const normalized = typeof value === 'string' ? value.replace(/[^\d.-]/g, '') : value;
  const parsed = Number(normalized);
  return Number.isFinite(parsed) ? parsed : fallback;
}

function toInt(value, fallback = 0) {
  return Math.trunc(toNumber(value, fallback));
}

function parseDeductions(body) {
  const labels = Array.isArray(body.deduction_label)
    ? body.deduction_label
    : body.deduction_label
      ? [body.deduction_label]
      : [];
  const amounts = Array.isArray(body.deduction_amount)
    ? body.deduction_amount
    : body.deduction_amount
      ? [body.deduction_amount]
      : [];

  return labels
    .map((label, index) => ({
      label: String(label || '').trim(),
      amount: toInt(amounts[index])
    }))
    .filter((item) => item.label || item.amount !== 0);
}

function calculateBon(input) {
  const netto1 = toInt(input.netto_1);
  const netto2 = toInt(input.netto_2);
  const price = toInt(input.price);
  const dp = toInt(input.dp);
  const biayaBongkar = toInt(input.biaya_bongkar);
  const bpColt = toInt(input.bp_colt);
  const pph = input.pph === undefined || input.pph === ''
    ? Math.floor(0.0025 * price * netto2)
    : toInt(input.pph);
  const uangMinum = input.uang_minum === undefined || input.uang_minum === ''
    ? (netto2 > 8000 ? 20000 : 10000)
    : toInt(input.uang_minum);
  const deductions = input.deductions || [];
  const potLain = deductions.reduce((sum, item) => sum + toInt(item.amount), 0);
  const subtotal = price * netto2;
  const totalBiayaBongkar = biayaBongkar * netto1;
  const total = subtotal - (dp + totalBiayaBongkar + bpColt + pph + uangMinum + potLain);

  return {
    netto_1: netto1,
    netto_2: netto2,
    price,
    dp,
    biaya_bongkar: biayaBongkar,
    bp_colt: bpColt,
    pph,
    uang_minum: uangMinum,
    pot_lain: potLain,
    subtotal,
    total_biaya_bongkar: totalBiayaBongkar,
    total
  };
}

function nextDay(dateString) {
  const date = new Date(`${dateString}T00:00:00`);
  date.setDate(date.getDate() + 1);
  return date.toISOString().slice(0, 10);
}

function nowInvoiceNumber() {
  return `NOTA-${Date.now()}`;
}

module.exports = {
  PAYMENT_STATUS,
  calculateBon,
  nextDay,
  nowInvoiceNumber,
  parseDeductions,
  toInt,
  toNumber
};
