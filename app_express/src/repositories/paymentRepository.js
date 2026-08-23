const { applyDateRange, assertNoError } = require('./base');
const { PAYMENT_STATUS, toInt } = require('../services/calculations');
const { getTotalDeposits } = require('./depositRepository');
const { notifyChange } = require('../services/realtimeService');

async function getTotalPayments(supabase) {
  const rows = assertNoError(await supabase.from('payments').select('amount_paid'));
  return rows.reduce((sum, row) => sum + toInt(row.amount_paid), 0);
}

async function getCurrentBalance(supabase) {
  return (await getTotalDeposits(supabase)) - (await getTotalPayments(supabase));
}

async function listPayments(supabase, filters = {}) {
  const CHUNK = 80;
  const buildQuery = (invoiceIds) => {
    let q = supabase.from('payments').select('*, notas(id, invoice_number, total_amount)');
    q = applyDateRange(q, 'payment_date', filters.start, filters.end);
    if (invoiceIds) q = q.in('invoice_id', invoiceIds);
    return q.order('payment_date', { ascending: false });
  };

  if (!filters.factory_id) {
    return assertNoError(await buildQuery(null));
  }

  // Batasi pencarian bon ke rentang tanggal yang sama agar daftar id tetap kecil.
  let bonsQuery = supabase.from('bons').select('id').eq('factory_id', filters.factory_id);
  bonsQuery = applyDateRange(bonsQuery, 'bon_date', filters.start, filters.end);
  const bons = assertNoError(await bonsQuery);
  const bonIds = bons.map((bon) => bon.id);
  if (bonIds.length === 0) return [];

  // Ambil invoice_id ber-batch agar URL PostgREST tidak melebihi batas panjang.
  const notaIds = new Set();
  for (let i = 0; i < bonIds.length; i += CHUNK) {
    const chunk = bonIds.slice(i, i + CHUNK);
    const items = assertNoError(
      await supabase.from('nota_items').select('invoice_id').in('bon_id', chunk)
    );
    items.forEach((item) => notaIds.add(item.invoice_id));
  }
  const ids = [...notaIds];
  if (ids.length === 0) return [];

  const payments = [];
  for (let i = 0; i < ids.length; i += CHUNK) {
    const chunk = ids.slice(i, i + CHUNK);
    payments.push(...assertNoError(await buildQuery(chunk)));
  }
  payments.sort((a, b) => new Date(b.payment_date) - new Date(a.payment_date));
  return payments;
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
  if (amount > balance) console.warn('Saldo tidak mencukupi. Tersedia:', balance, 'Dibayar:', amount);

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
  notifyChange('payments', 'INSERT', payment);
  return payment;
}

async function settleNotaWithoutProof(supabase, notaId, { amountPaid, paymentDate }) {
  const nota = assertNoError(await supabase.from('notas').select('id,status').eq('id', notaId).single());
  if (nota.status === PAYMENT_STATUS.LUNAS) throw new Error('Nota sudah lunas.');

  const payment = assertNoError(
    await supabase
      .from('payments')
      .insert({
        invoice_id: notaId,
        payment_date: paymentDate || new Date().toISOString(),
        amount_paid: toInt(amountPaid),
        proof_url: null,
        margin_id: null
      })
      .select()
      .single()
  );

  assertNoError(await supabase.from('notas').update({ status: PAYMENT_STATUS.LUNAS }).eq('id', notaId));
  const items = assertNoError(await supabase.from('nota_items').select('bon_id').eq('invoice_id', notaId));
  const bonIds = items.map((item) => item.bon_id);
  if (bonIds.length > 0) {
    assertNoError(await supabase.from('bons').update({ status: PAYMENT_STATUS.LUNAS }).in('id', bonIds));
  }
  notifyChange('payments', 'INSERT', payment);
  return payment;
}

async function updatePayment(supabase, id, body) {
  const payment = assertNoError(await supabase.from('payments').select().eq('id', id).single());
  if (payment.margin_id) throw new Error('Pembayaran sudah tercatat dalam margin, tidak dapat diedit.');

  const amount = body.amount_paid === undefined ? toInt(payment.amount_paid) : toInt(body.amount_paid);
  const balance = (await getCurrentBalance(supabase)) + toInt(payment.amount_paid);
  if (amount > balance) console.warn('Saldo tidak mencukupi. Tersedia:', balance, 'Dibayar:', amount);

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
  const build = (select) => {
    let query = supabase.from('payments').select(select);
    if (includeMarginId) query = query.or(`margin_id.is.null,margin_id.eq.${includeMarginId}`);
    else query = query.is('margin_id', null);
    return query.order('payment_date', { ascending: false });
  };
  const enriched =
    '*, notas(invoice_number, invoice_date, recipient_name, nota_items(bons(*, sub_notas(*), factories(name))))';
  const base =
    '*, notas(invoice_number, invoice_date, recipient_name, nota_items(bons(*, factories(name))))';
  try {
    return assertNoError(await build(enriched));
  } catch (subError) {
    // Tabel sub_notas mungkin belum migrasi → fallback tanpa sub nota.
    return assertNoError(await build(base));
  }
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
  settleNotaWithoutProof,
  updatePayment
};
