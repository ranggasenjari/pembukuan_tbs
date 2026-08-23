const { assertNoError } = require('./base');
const { notifyChange } = require('../services/realtimeService');
const { toInt } = require('../services/calculations');

// Sub Nota: catatan tambahan pada sebuah bon. Tidak ikut alur nota/pembayaran — hanya tercatat & laporan.

async function listByBon(supabase, bonId) {
  return assertNoError(
    await supabase.from('sub_notas').select('*').eq('bon_id', bonId).order('created_at', { ascending: false })
  );
}

async function getSubNota(supabase, id) {
  return assertNoError(
    await supabase.from('sub_notas').select('*').eq('id', id).single()
  );
}

async function createForBon(supabase, bonId, body) {
  const name = String(body.name || '').trim().toUpperCase();
  if (!name) throw new Error('Nama wajib diisi.');
  const pricePerKg = toInt(body.price_per_kg);
  if (pricePerKg <= 0) throw new Error('Harga (Rp/kg) wajib lebih dari 0.');

  const bon = assertNoError(
    await supabase.from('bons').select('netto_2').eq('id', bonId).single()
  );
  const netto2 = toInt(bon.netto_2);
  const amount = netto2 * pricePerKg;

  const created = assertNoError(
    await supabase
      .from('sub_notas')
      .insert({
        bon_id: bonId,
        name,
        price_per_kg: pricePerKg,
        netto_2: netto2,
        amount,
        notes: body.notes ? String(body.notes).trim() : null
      })
      .select()
      .single()
  );

  notifyChange('sub_notas', 'INSERT', created);
  return created;
}

async function deleteSubNota(supabase, id) {
  const existing = await getSubNota(supabase, id);
  assertNoError(await supabase.from('sub_notas').delete().eq('id', id));
  notifyChange('sub_notas', 'DELETE', null, existing);
  return existing;
}

module.exports = {
  createForBon,
  deleteSubNota,
  getSubNota,
  listByBon
};