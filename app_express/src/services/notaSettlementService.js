const { assertNoError } = require('../repositories/base');
const { PAYMENT_STATUS, toInt } = require('./calculations');

const DEFAULT_PROOF_URL = 'https://example.invalid/pembukuan/auto-settlement-proof';

function sumPayments(payments) {
  return payments.reduce((sum, payment) => sum + toInt(payment.amount_paid), 0);
}

async function getNotaBonIds(supabase, notaId) {
  const items = assertNoError(
    await supabase.from('nota_items').select('bon_id').eq('invoice_id', notaId)
  );
  return [...new Set(items.map((item) => item.bon_id).filter(Boolean))];
}

async function getOutstandingNotas(supabase) {
  const notas = assertNoError(
    await supabase
      .from('notas')
      .select('id,invoice_number,invoice_date,total_amount,status')
  );

  const rows = [];
  for (const nota of notas) {
    const totalAmount = toInt(nota.total_amount);
    const payments = assertNoError(
      await supabase.from('payments').select('amount_paid').eq('invoice_id', nota.id)
    );
    const paidAmount = sumPayments(payments);
    const outstandingAmount = Math.max(totalAmount - paidAmount, 0);
    const needsStatusSync = nota.status !== PAYMENT_STATUS.LUNAS;

    rows.push({
      id: nota.id,
      invoice_number: nota.invoice_number,
      invoice_date: nota.invoice_date,
      status: nota.status,
      totalAmount,
      paidAmount,
      outstandingAmount,
      needsStatusSync
    });
  }

  return rows;
}

async function settleAllNotas(supabase, options = {}) {
  const dryRun = options.dryRun !== false;
  const fallbackPaymentDate = options.paymentDate || new Date().toISOString();
  const proofUrl = options.proofUrl || DEFAULT_PROOF_URL;
  const source = options.source || `Cleanup otomatis pelunasan nota ${fallbackPaymentDate.slice(0, 10)}`;
  const category = options.category || 'kredit';

  const rows = await getOutstandingNotas(supabase);
  const payableRows = rows.filter((row) => row.outstandingAmount > 0);
  const statusOnlyRows = rows.filter((row) => row.outstandingAmount <= 0 && row.needsStatusSync);
  const totalPaymentAmount = payableRows.reduce((sum, row) => sum + row.outstandingAmount, 0);

  const summary = {
    dryRun,
    scannedNotas: rows.length,
    payableNotas: payableRows.length,
    statusOnlyNotas: statusOnlyRows.length,
    skippedFullySettled: rows.length - payableRows.length - statusOnlyRows.length,
    totalPaymentAmount,
    depositCreated: false,
    paymentsCreated: 0,
    notasMarkedLunas: 0,
    bonsMarkedLunas: 0,
    proofUrl,
    deposit: totalPaymentAmount > 0
      ? { source, category, amount: totalPaymentAmount, created_at: fallbackPaymentDate }
      : null,
    candidates: payableRows.map((row) => ({
      id: row.id,
      invoice_number: row.invoice_number,
      status: row.status,
      invoice_date: row.invoice_date,
      total_amount: row.totalAmount,
      paid_amount: row.paidAmount,
      payment_amount: row.outstandingAmount,
      payment_date: row.invoice_date || fallbackPaymentDate
    }))
  };

  if (dryRun) return summary;

  if (totalPaymentAmount > 0) {
    assertNoError(
      await supabase.from('deposits').insert({
        source,
        amount: totalPaymentAmount,
        category,
        created_at: fallbackPaymentDate
      })
    );
    summary.depositCreated = true;
  }

  for (const row of payableRows) {
    assertNoError(
      await supabase.from('payments').insert({
        invoice_id: row.id,
        payment_date: row.invoice_date || fallbackPaymentDate,
        amount_paid: row.outstandingAmount,
        proof_url: proofUrl,
        margin_id: null
      })
    );
    summary.paymentsCreated += 1;
  }

  for (const row of [...payableRows, ...statusOnlyRows]) {
    assertNoError(
      await supabase.from('notas').update({ status: PAYMENT_STATUS.LUNAS }).eq('id', row.id)
    );
    summary.notasMarkedLunas += 1;

    const bonIds = await getNotaBonIds(supabase, row.id);
    if (bonIds.length > 0) {
      assertNoError(
        await supabase.from('bons').update({ status: PAYMENT_STATUS.LUNAS }).in('id', bonIds)
      );
      summary.bonsMarkedLunas += bonIds.length;
    }
  }

  return summary;
}

module.exports = {
  DEFAULT_PROOF_URL,
  getOutstandingNotas,
  settleAllNotas
};
