const { applyDateRange, assertNoError } = require('./base');
const { PAYMENT_STATUS, applyFactoryDeductionPresets } = require('../services/calculations');
const { notifyChange } = require('../services/realtimeService');

function serializeBon(body, calculated, imageUrl) {
  const data = {
    ticket_number: body.ticket_number || null,
    bon_date: body.bon_date,
    plate_number: String(body.plate_number || '').replace(/\s+/g, '').toUpperCase(),
    driver_name: body.driver_name ? String(body.driver_name).trim().toUpperCase() : null,
    relation_name: body.relation_agent_id ? null : (body.relation_name ? String(body.relation_name).trim().toUpperCase() : null),
    relation_agent_id: body.relation_agent_id || null,
    factory_id: body.factory_id || null,
    factory_spsi_type_id: body.factory_spsi_type_id || null,
    spsi_type_name: body.spsi_type_name ? String(body.spsi_type_name).trim().toUpperCase() : null,
    spsi_calculation_mode: calculated.spsi_calculation_mode,
    spsi_rate: calculated.spsi_rate,
    spsi_amount: calculated.spsi_amount,
    fruit_origin: body.fruit_origin ? String(body.fruit_origin).trim().toUpperCase() : null,
    chat_id: body.chat_id || null,
    message_id: body.message_id || null,
    notes: body.notes || null,
    netto_1: calculated.netto_1,
    netto_2: calculated.netto_2,
    price: calculated.price,
    dp: calculated.dp,
    biaya_bongkar: calculated.biaya_bongkar,
    bp_colt: calculated.bp_colt,
    pph: calculated.pph,
    uang_minum: calculated.uang_minum,
    total: calculated.total,
    status: body.status || PAYMENT_STATUS.BELUM_DIBAYAR
  };

  if (imageUrl) data.image_url = imageUrl;
  return data;
}

async function listBons(supabase, filters = {}) {
  let query = supabase.from('bons').select('*, bon_deductions(*), factories(name), relation_agents(name)');
  query = applyDateRange(query, 'bon_date', filters.start, filters.end);
  if (filters.status) query = query.eq('status', filters.status);
  if (filters.q) {
    const q = String(filters.q).trim();
    query = query.or(`driver_name.ilike.%${q}%,plate_number.ilike.%${q}%,relation_name.ilike.%${q}%`);
  }
  if (filters.factory_id) query = query.eq('factory_id', filters.factory_id);
  return assertNoError(await query.order('created_at', { ascending: false }));
}

async function getBon(supabase, id) {
  return assertNoError(
    await supabase.from('bons').select('*, bon_deductions(*), factories(name), relation_agents(name)').eq('id', id).single()
  );
}

async function getLatestPrice(supabase) {
  const { data, error } = await supabase
    .from('bons')
    .select('price')
    .order('created_at', { ascending: false })
    .limit(1)
    .maybeSingle();
  if (error) throw error;
  return data?.price || 0;
}

async function createBon(supabase, data, deductions = []) {
  const created = assertNoError(
    await supabase.from('bons').insert(data).select().single()
  );

  const deductionsToSave = applyFactoryDeductionPresets(data.factory_id, deductions);
  if (deductionsToSave.length > 0) {
    assertNoError(
      await supabase.from('bon_deductions').insert(
        deductionsToSave.map((item) => ({
          bon_id: created.id,
          label: item.label,
          amount: item.amount
        }))
      )
    );
  }

  notifyChange('bons', 'INSERT', created);
  return getBon(supabase, created.id);
}

async function updateBon(supabase, id, data, deductions = [], skipStatusCheck = false) {
  if (!skipStatusCheck) {
    const current = assertNoError(await supabase.from('bons').select('status').eq('id', id).single());
    if (current.status === PAYMENT_STATUS.LUNAS) {
      throw new Error('Bon sudah lunas, tidak dapat diedit.');
    }
  }

  assertNoError(await supabase.from('bons').update(data).eq('id', id));
  assertNoError(await supabase.from('bon_deductions').delete().eq('bon_id', id));
  if (deductions.length > 0) {
    assertNoError(
      await supabase.from('bon_deductions').insert(
        deductions.map((item) => ({ bon_id: id, label: item.label, amount: item.amount }))
      )
    );
  }
  const updated = await getBon(supabase, id);
  notifyChange('bons', 'UPDATE', updated);
  return updated;
}

async function deleteBon(supabase, id) {
  const current = assertNoError(await supabase.from('bons').select('status, image_url, plate_number, ticket_number').eq('id', id).single());
  if (current.status !== PAYMENT_STATUS.BELUM_DIBAYAR) {
    throw new Error('Bon sudah diproses (Tertagih/Lunas), tidak dapat dihapus.');
  }
  // Hapus file dari bucket jika ada
  if (current.image_url) {
    const pathMatch = current.image_url.match(/\/object\/public\/[^/]+\/(.+)$/);
    if (pathMatch) {
      const filePath = pathMatch[1];
      await supabase.storage.from('receipts').remove([filePath]).catch(() => {});
    }
  }
  assertNoError(await supabase.from('bons').delete().eq('id', id));
  notifyChange('bons', 'DELETE', null, current);
}

async function getRelatedRecords(supabase, bonId) {
  const notaItems = assertNoError(
    await supabase.from('nota_items').select('notas(*)').eq('bon_id', bonId)
  );
  const notas = (notaItems || []).map((item) => item.notas).filter(Boolean);
  if (notas.length === 0) return { notas: [], payments: [] };

  const notaIds = notas.map((nota) => nota.id);
  const payments = assertNoError(
    await supabase.from('payments').select('*, notas(invoice_number)').in('invoice_id', notaIds)
  );
  return { notas, payments };
}

module.exports = {
  createBon,
  deleteBon,
  getBon,
  getLatestPrice,
  getRelatedRecords,
  listBons,
  serializeBon,
  updateBon
};
