const { applyDateRange, assertNoError } = require('./base');
const { PAYMENT_STATUS, nowInvoiceNumber } = require('../services/calculations');

async function listNotas(supabase, filters = {}) {
  let query = supabase.from('notas').select('*, nota_items(count)');
  query = applyDateRange(query, 'invoice_date', filters.start, filters.end);

  if (filters.q) {
    const bons = assertNoError(
      await supabase.from('bons').select('id').ilike('driver_name', `%${filters.q}%`)
    );
    const bonIds = bons.map((bon) => bon.id);
    if (bonIds.length === 0) return [];
    const items = assertNoError(
      await supabase.from('nota_items').select('invoice_id').in('bon_id', bonIds)
    );
    const notaIds = [...new Set(items.map((item) => item.invoice_id))];
    if (notaIds.length === 0) return [];
    query = query.in('id', notaIds);
  }

  return assertNoError(await query.order('invoice_date', { ascending: false }));
}

async function getNota(supabase, id) {
  return assertNoError(
    await supabase.from('notas').select('*, nota_items(count)').eq('id', id).single()
  );
}

async function getNotaBons(supabase, notaId) {
  const rows = assertNoError(
    await supabase.from('nota_items').select('bons(*, bon_deductions(*))').eq('invoice_id', notaId)
  );
  return rows.map((row) => row.bons).filter(Boolean);
}

async function getAvailableBonsForNota(supabase, notaId = null) {
  const allBons = assertNoError(
    await supabase.from('bons').select('*, bon_deductions(*)').order('bon_date', { ascending: false })
  );
  if (!notaId) return allBons.filter((bon) => bon.status === PAYMENT_STATUS.BELUM_DIBAYAR);

  const currentBons = await getNotaBons(supabase, notaId);
  const currentIds = new Set(currentBons.map((bon) => bon.id));
  return allBons.filter((bon) => bon.status === PAYMENT_STATUS.BELUM_DIBAYAR || currentIds.has(bon.id));
}

async function createNota(supabase, body, bonIds) {
  if (!bonIds.length) throw new Error('Pilih minimal satu bon.');
  const selected = assertNoError(await supabase.from('bons').select('id,total,status').in('id', bonIds));
  if (selected.some((bon) => bon.status !== PAYMENT_STATUS.BELUM_DIBAYAR)) {
    throw new Error('Semua bon yang dipilih harus berstatus BELUM_DIBAYAR.');
  }
  const totalAmount = selected.reduce((sum, bon) => sum + Number(bon.total || 0), 0);

  const nota = assertNoError(
    await supabase
      .from('notas')
      .insert({
        invoice_number: nowInvoiceNumber(),
        invoice_date: new Date().toISOString(),
        total_amount: totalAmount,
        status: PAYMENT_STATUS.TERTAGIH,
        recipient_name: String(body.recipient_name || '').trim().toUpperCase(),
        recipient_address: body.recipient_address ? String(body.recipient_address).trim().toUpperCase() : null
      })
      .select()
      .single()
  );

  assertNoError(
    await supabase.from('nota_items').insert(
      bonIds.map((bonId) => ({ invoice_id: nota.id, bon_id: bonId }))
    )
  );
  assertNoError(await supabase.from('bons').update({ status: PAYMENT_STATUS.TERTAGIH }).in('id', bonIds));
  return nota;
}

async function updateNota(supabase, id, body, newBonIds) {
  if (!newBonIds.length) throw new Error('Pilih minimal satu bon.');
  const nota = await getNota(supabase, id);
  const currentBons = await getNotaBons(supabase, id);
  const currentIds = currentBons.map((bon) => bon.id);
  const toRemove = currentIds.filter((bonId) => !newBonIds.includes(bonId));
  const toAdd = newBonIds.filter((bonId) => !currentIds.includes(bonId));

  if (toAdd.length > 0) {
    const addCandidates = assertNoError(await supabase.from('bons').select('id,status').in('id', toAdd));
    if (addCandidates.some((bon) => bon.status !== PAYMENT_STATUS.BELUM_DIBAYAR)) {
      throw new Error('Bon tambahan harus berstatus BELUM_DIBAYAR.');
    }
  }

  const allSelected = assertNoError(await supabase.from('bons').select('id,total').in('id', newBonIds));
  const totalAmount = allSelected.reduce((sum, bon) => sum + Number(bon.total || 0), 0);

  assertNoError(
    await supabase
      .from('notas')
      .update({
        total_amount: totalAmount,
        status: nota.status,
        recipient_name: String(body.recipient_name || '').trim().toUpperCase(),
        recipient_address: body.recipient_address ? String(body.recipient_address).trim().toUpperCase() : null
      })
      .eq('id', id)
  );

  if (toRemove.length > 0) {
    assertNoError(await supabase.from('nota_items').delete().eq('invoice_id', id).in('bon_id', toRemove));
    assertNoError(await supabase.from('bons').update({ status: PAYMENT_STATUS.BELUM_DIBAYAR }).in('id', toRemove));
  }
  if (toAdd.length > 0) {
    assertNoError(await supabase.from('nota_items').insert(toAdd.map((bonId) => ({ invoice_id: id, bon_id: bonId }))));
    assertNoError(await supabase.from('bons').update({ status: PAYMENT_STATUS.TERTAGIH }).in('id', toAdd));
  }

  return getNota(supabase, id);
}

async function deleteNota(supabase, id) {
  const payments = assertNoError(await supabase.from('payments').select('id').eq('invoice_id', id).limit(1));
  if (payments.length > 0) throw new Error('Nota sudah memiliki pembayaran, tidak dapat dihapus.');
  const bons = await getNotaBons(supabase, id);
  const bonIds = bons.map((bon) => bon.id);
  if (bonIds.length > 0) {
    assertNoError(await supabase.from('bons').update({ status: PAYMENT_STATUS.BELUM_DIBAYAR }).in('id', bonIds));
  }
  assertNoError(await supabase.from('nota_items').delete().eq('invoice_id', id));
  assertNoError(await supabase.from('notas').delete().eq('id', id));
}

module.exports = {
  createNota,
  deleteNota,
  getAvailableBonsForNota,
  getNota,
  getNotaBons,
  listNotas,
  updateNota
};
