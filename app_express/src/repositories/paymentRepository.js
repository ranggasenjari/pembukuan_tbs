const { applyDateRange, assertNoError } = require('./base');
const { PAYMENT_STATUS, toInt } = require('../services/calculations');
const { getTotalDeposits } = require('./depositRepository');

async function getTotalPayments(supabase) {
  const rows = assertNoError(await supabase.from('payments').select('amount_paid'));
  return rows.reduce((sum, row) => sum + toInt(row.amount_paid), 0);
}

async function getCurrentBalance(supabase) {
  return (await getTotalDeposits(supabase)) - (await getTotalPayments(supabase));
}

async function listPayments(supabase, filters = {}) {
  let query = supabase.from('payments').select('*, notas(id, invoice_number, total_amount)');
  query = applyDateRange(query, 'payment_date', filters.start, filters.end);
  return assertNoError(await query.order('payment_date', { ascending: false }));
}

async function listPaymentsByNota(supabase, notaId) {
  return assertNoError(
    await supabase.from('payments').select().eq('invoice_id', notaId).order('created_at', { ascending: false })
  );
}

async function getPayment(supabase, id) {
  return assertNoError(await supabase.from('payments').select('*, notas(*)').eq('id', id).single());
}

async function listPayableNotas(supabase) {
  return assertNoError(
    await supabase.from('notas').select('*, nota_items(count)').eq('status', PAYMENT_STATUS.TERTAGIH).order('invoice_date', { ascending: false })
  );
}

async function createPayment(supabase, body, proofUrl) {
  if (!proofUrl) throw new Error('Bukti pembayaran wajib diupload.');
  const amount = toInt(body.amount_paid);
  const balance = await getCurrentBalance(supabase);
  if (amount > balance) throw new Error(`Saldo tidak mencukupi. Tersedia: ${balance}`);

  const payment = assertNoError(
    await supabase
      .from('payments')
      .insert({
        invoice_id: body.invoice_id,
        payment_date: body.payment_date || new Date().toISOString(),
        amount_paid: amount,
        proof_url: proofUrl,
        margin_id: null
      })
      .select()
      .single()
  );

  assertNoError(await supabase.from('notas').update({ status: PAYMENT_STATUS.LUNAS }).eq('id', body.invoice_id));
  const items = assertNoError(await supabase.from('nota_items').select('bon_id').eq('invoice_id', body.invoice_id));
  const bonIds = items.map((item) => item.bon_id);
  if (bonIds.length > 0) {
    assertNoError(await supabase.from('bons').update({ status: PAYMENT_STATUS.LUNAS }).in('id', bonIds));
  }
  return payment;
}

async function updatePayment(supabase, id, body) {
  const payment = assertNoError(await supabase.from('payments').select().eq('id', id).single());
  if (payment.margin_id) throw new Error('Pembayaran sudah tercatat dalam margin, tidak dapat diedit.');

  const amount = body.amount_paid === undefined ? toInt(payment.amount_paid) : toInt(body.amount_paid);
  const balance = (await getCurrentBalance(supabase)) + toInt(payment.amount_paid);
  if (amount > balance) throw new Error(`Saldo tidak mencukupi. Tersedia: ${balance}`);

  const updates = { amount_paid: amount };
  if (body.payment_date !== undefined) updates.payment_date = body.payment_date || payment.payment_date;

  return assertNoError(
    await supabase
      .from('payments')
      .update(updates)
      .eq('id', id)
      .select()
      .single()
  );
}

async function deletePayment(supabase, id) {
  const payment = assertNoError(await supabase.from('payments').select().eq('id', id).single());
  if (payment.margin_id) throw new Error('Pembayaran sudah tercatat dalam margin, tidak dapat dihapus.');

  assertNoError(await supabase.from('payments').delete().eq('id', id));
  if (payment.invoice_id) {
    assertNoError(await supabase.from('notas').update({ status: PAYMENT_STATUS.TERTAGIH }).eq('id', payment.invoice_id));
    const items = assertNoError(await supabase.from('nota_items').select('bon_id').eq('invoice_id', payment.invoice_id));
    const bonIds = items.map((item) => item.bon_id);
    if (bonIds.length > 0) {
      assertNoError(await supabase.from('bons').update({ status: PAYMENT_STATUS.TERTAGIH }).in('id', bonIds));
    }
  }
}

async function getUnassignedPayments(supabase, includeMarginId = null) {
  let query = supabase.from('payments').select('*, notas(invoice_number)');
  if (includeMarginId) query = query.or(`margin_id.is.null,margin_id.eq.${includeMarginId}`);
  else query = query.is('margin_id', null);
  return assertNoError(await query.order('payment_date', { ascending: false }));
}

module.exports = {
  createPayment,
  deletePayment,
  getCurrentBalance,
  getPayment,
  getTotalPayments,
  getUnassignedPayments,
  listPayableNotas,
  listPayments,
  listPaymentsByNota,
  updatePayment
};
