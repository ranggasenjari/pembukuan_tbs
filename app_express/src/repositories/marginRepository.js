const { applyDateRange, assertNoError } = require('./base');
const { toInt } = require('../services/calculations');
const { getUnassignedPayments } = require('./paymentRepository');

async function listMargins(supabase, filters = {}) {
  let query = supabase.from('margins').select('*, factories(name)');
  query = applyDateRange(query, 'transaction_date', filters.start, filters.end);
  return assertNoError(await query.order('transaction_date', { ascending: false }));
}

async function getMargin(supabase, id) {
  return assertNoError(await supabase.from('margins').select('*, factories(name)').eq('id', id).single());
}

async function createMargin(supabase, body, paymentIds) {
  if (!paymentIds.length) throw new Error('Pilih minimal satu pembayaran.');
  const payments = assertNoError(await supabase.from('payments').select('id,amount_paid,margin_id').in('id', paymentIds));
  if (payments.some((payment) => payment.margin_id)) {
    throw new Error('Pembayaran yang dipilih sudah masuk margin lain.');
  }
  const realAmount = payments.reduce((sum, payment) => sum + toInt(payment.amount_paid), 0);
  const offtakerAmount = toInt(body.offtaker_amount);
  if (offtakerAmount <= realAmount) throw new Error('Jumlah bayar offtaker harus lebih besar dari total real pembayaran.');

  const margin = assertNoError(
    await supabase
      .from('margins')
      .insert({
        transaction_date: body.transaction_date || new Date().toISOString(),
        factory_id: body.factory_id || null,
        offtaker_amount: offtakerAmount,
        real_amount: realAmount,
        margin_amount: offtakerAmount - realAmount
      })
      .select()
      .single()
  );
  assertNoError(await supabase.from('payments').update({ margin_id: margin.id }).in('id', paymentIds));
  return margin;
}

async function updateMargin(supabase, id, body, paymentIds) {
  if (!paymentIds.length) throw new Error('Pilih minimal satu pembayaran.');
  const existing = await getMargin(supabase, id);
  const payments = assertNoError(await supabase.from('payments').select('id,amount_paid,margin_id').in('id', paymentIds));
  if (payments.some((payment) => payment.margin_id && payment.margin_id !== id)) {
    throw new Error('Ada pembayaran yang sudah masuk margin lain.');
  }
  const realAmount = payments.reduce((sum, payment) => sum + toInt(payment.amount_paid), 0);
  const offtakerAmount = body.offtaker_amount === undefined
    ? toInt(existing.offtaker_amount)
    : toInt(body.offtaker_amount);
  if (offtakerAmount <= realAmount) throw new Error('Jumlah bayar offtaker harus lebih besar dari total real pembayaran.');

  assertNoError(
    await supabase
      .from('margins')
      .update({
        transaction_date: body.transaction_date || existing.transaction_date,
        factory_id: body.factory_id || null,
        offtaker_amount: offtakerAmount,
        real_amount: realAmount,
        margin_amount: offtakerAmount - realAmount
      })
      .eq('id', id)
  );
  assertNoError(await supabase.from('payments').update({ margin_id: null }).eq('margin_id', id));
  assertNoError(await supabase.from('payments').update({ margin_id: id }).in('id', paymentIds));
  return getMargin(supabase, id);
}

async function deleteMargin(supabase, id) {
  assertNoError(await supabase.from('payments').update({ margin_id: null }).eq('margin_id', id));
  assertNoError(await supabase.from('margins').delete().eq('id', id));
}

async function getMarginPayments(supabase, id) {
  return assertNoError(
    await supabase
      .from('payments')
      .select('*, notas(invoice_number, recipient_name, nota_items(bons(netto_2, price)))')
      .eq('margin_id', id)
  );
}

async function getMarginFormPayments(supabase, id = null) {
  return getUnassignedPayments(supabase, id);
}

module.exports = {
  createMargin,
  deleteMargin,
  getMargin,
  getMarginFormPayments,
  getMarginPayments,
  listMargins,
  updateMargin
};
