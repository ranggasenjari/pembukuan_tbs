const { applyDateRange, assertNoError } = require('./base');
const { PAYMENT_STATUS, nowInvoiceNumber } = require('../services/calculations');
const relationAgentRepository = require('./relationAgentRepository');
const { notifyChange } = require('../services/realtimeService');

async function resolveRecipient(supabase, body) {
  if (body.relation_agent_id) {
    const relation = await relationAgentRepository.getRelationAgent(supabase, body.relation_agent_id);
    return {
      relation_agent_id: relation.id,
      recipient_name: null,
      recipient_address: relation.address || null
    };
  }
  return {
    relation_agent_id: null,
    recipient_name: String(body.recipient_name || '').trim().toUpperCase(),
    recipient_address: body.recipient_address ? String(body.recipient_address).trim().toUpperCase() : null
  };
}

async function listNotas(supabase, filters = {}) {
  let query = supabase.from('notas').select('*, nota_items(bon_id, bons(plate_number, driver_name, netto_2, total)), relation_agents(name)');
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

  if (filters.factory_id) {
    const bons = assertNoError(
      await supabase.from('bons').select('id').eq('factory_id', filters.factory_id)
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

  return assertNoError(await query.order('created_at', { ascending: false }));
}

async function searchNotasByRecipient(supabase, recipientName, filters = {}) {
  const name = String(recipientName || '').trim();
  if (!name) return [];

  let query = supabase
    .from('notas')
    .select('*, nota_items(count), relation_agents!left(name)')
    .or(`recipient_name.ilike.%${name}%,relation_agents.name.ilike.%${name}%`);
  query = applyDateRange(query, 'invoice_date', filters.start, filters.end);
  if (filters.status) query = query.eq('status', filters.status);

  return assertNoError(await query.order('invoice_date', { ascending: false }));
}

async function getNota(supabase, id) {
  return assertNoError(
    await supabase.from('notas').select('*, nota_items(count), relation_agents(*, relation_agent_accounts(*))').eq('id', id).single()
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
    await supabase.from('bons').select('*, bon_deductions(*), factories(name), relation_agents(name)').order('bon_date', { ascending: false })
  );
  if (!notaId) return allBons.filter((bon) => bon.status === PAYMENT_STATUS.BELUM_DIBAYAR);

  const currentBons = await getNotaBons(supabase, notaId);
  const currentIds = new Set(currentBons.map((bon) => bon.id));
  return allBons.filter((bon) => bon.status === PAYMENT_STATUS.BELUM_DIBAYAR || currentIds.has(bon.id));
}

async function createNota(supabase, body, bonIds) {
  if (!bonIds.length) throw new Error('Pilih minimal satu bon.');
  const recipient = await resolveRecipient(supabase, body);
  if (!recipient.relation_agent_id && !recipient.recipient_name) throw new Error('Pilih Relasi / Agen penerima nota.');
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
        relation_agent_id: recipient.relation_agent_id,
        recipient_name: recipient.recipient_name,
        recipient_address: recipient.recipient_address
      })
      .select('*, relation_agents(*, relation_agent_accounts(*))')
      .single()
  );

  assertNoError(
    await supabase.from('nota_items').insert(
      bonIds.map((bonId) => ({ invoice_id: nota.id, bon_id: bonId }))
    )
  );
  assertNoError(await supabase.from('bons').update({ status: PAYMENT_STATUS.TERTAGIH }).in('id', bonIds));
  notifyChange('notas', 'INSERT', nota);
  return nota;
}

async function updateNota(supabase, id, body, newBonIds) {
  if (!newBonIds.length) throw new Error('Pilih minimal satu bon.');
  const recipient = await resolveRecipient(supabase, body);
  if (!recipient.relation_agent_id && !recipient.recipient_name) throw new Error('Pilih Relasi / Agen penerima nota.');
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
        relation_agent_id: recipient.relation_agent_id,
        recipient_name: recipient.recipient_name,
        recipient_address: recipient.recipient_address
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

async function mergeBonsIntoNota(supabase, bonIds, relationAgentId = null) {
  const ids = [...new Set((bonIds || []).map((id) => String(id)).filter(Boolean))];
  if (ids.length < 2) throw new Error('Pilih minimal dua bon untuk digabung.');

  const selected = assertNoError(await supabase.from('bons').select('id,status,total,relation_agent_id,relation_name,driver_name,plate_number').in('id', ids));
  if (selected.length !== ids.length) throw new Error('Ada bon yang tidak ditemukan.');
  if (selected.some((bon) => bon.status === PAYMENT_STATUS.LUNAS)) {
    throw new Error('Bon LUNAS tidak dapat digabung.');
  }

  // Cek pembayaran pada nota yang menampung bon-bon terpilih
  const notaItems = assertNoError(
    await supabase.from('nota_items').select('invoice_id, bon_id').in('bon_id', ids)
  );
  const notaIds = [...new Set(notaItems.map((item) => item.invoice_id))];
  if (notaIds.length > 0) {
    const payments = assertNoError(
      await supabase.from('payments').select('invoice_id').in('invoice_id', notaIds).limit(1)
    );
    if (payments.length > 0) {
      throw new Error('Salah satu nota sudah memiliki pembayaran, tidak dapat digabung.');
    }
  }

  // Hapus nota eksisting (penuh) atau keluarkan bon terpilih dari nota (parsial)
  const selectedSet = new Set(ids);
  for (const notaId of notaIds) {
    const notaBons = await getNotaBons(supabase, notaId);
    const notaBonIds = notaBons.map((bon) => bon.id);
    const allInSelection = notaBonIds.length > 0 && notaBonIds.every((id) => selectedSet.has(id));
    if (allInSelection) {
      await deleteNota(supabase, notaId);
    } else {
      const toRemove = notaBonIds.filter((id) => selectedSet.has(id));
      if (toRemove.length) {
        assertNoError(await supabase.from('nota_items').delete().eq('invoice_id', notaId).in('bon_id', toRemove));
        assertNoError(await supabase.from('bons').update({ status: PAYMENT_STATUS.BELUM_DIBAYAR }).in('id', toRemove));
        const remainingTotal = notaBons
          .filter((bon) => !selectedSet.has(bon.id))
          .reduce((sum, bon) => sum + Number(bon.total || 0), 0);
        assertNoError(await supabase.from('notas').update({ total_amount: remainingTotal }).eq('id', notaId));
      }
    }
  }

  // Tentukan relasi: id yang sama → pakai; relation_name sama → pakai nama; selain itu wajib dikirim relation_agent_id
  const relIds = [...new Set(selected.map((bon) => bon.relation_agent_id).filter(Boolean))];
  const relNames = [...new Set(selected.map((bon) => bon.relation_name).filter(Boolean))];
  let body;
  if (relationAgentId) body = { relation_agent_id: relationAgentId };
  else if (relIds.length === 1) body = { relation_agent_id: relIds[0] };
  else if (relNames.length === 1) body = { recipient_name: relNames[0] };
  else throw new Error('Relasi antar bon berbeda. Pilih relasi untuk nota gabungan.');

  return createNota(supabase, body, ids);
}

async function deleteNota(supabase, id) {
  const nota = await getNota(supabase, id);
  const payments = assertNoError(await supabase.from('payments').select('id').eq('invoice_id', id).limit(1));
  if (payments.length > 0) throw new Error('Nota sudah memiliki pembayaran, tidak dapat dihapus.');
  const bons = await getNotaBons(supabase, id);
  const bonIds = bons.map((bon) => bon.id);
  if (bonIds.length > 0) {
    assertNoError(await supabase.from('bons').update({ status: PAYMENT_STATUS.BELUM_DIBAYAR }).in('id', bonIds));
  }
  assertNoError(await supabase.from('nota_items').delete().eq('invoice_id', id));
  assertNoError(await supabase.from('notas').delete().eq('id', id));
  notifyChange('notas', 'DELETE', null, nota);
}

module.exports = {
  createNota,
  deleteNota,
  getAvailableBonsForNota,
  getNota,
  getNotaBons,
  listNotas,
  mergeBonsIntoNota,
  searchNotasByRecipient,
  updateNota
};
