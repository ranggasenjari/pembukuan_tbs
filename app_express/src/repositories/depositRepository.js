const { applyDateRange, assertNoError } = require('./base');
const { toInt } = require('../services/calculations');

async function listDeposits(supabase, filters = {}) {
  let query = supabase.from('deposits').select();
  query = applyDateRange(query, 'created_at', filters.start, filters.end);
  if (filters.category && filters.category !== 'Semua') query = query.eq('category', filters.category);
  return assertNoError(await query.order('created_at', { ascending: false }));
}

async function getTotalDeposits(supabase) {
  const rows = assertNoError(await supabase.from('deposits').select('amount'));
  return rows.reduce((sum, row) => sum + toInt(row.amount), 0);
}

async function createDeposit(supabase, body) {
  return assertNoError(
    await supabase
      .from('deposits')
      .insert({
        source: String(body.source || '').trim(),
        amount: toInt(body.amount),
        category: body.category || null,
        created_at: body.created_at || new Date().toISOString()
      })
      .select()
      .single()
  );
}

async function getDeposit(supabase, id) {
  return assertNoError(await supabase.from('deposits').select().eq('id', id).single());
}

async function updateDeposit(supabase, id, body) {
  const existing = await getDeposit(supabase, id);
  return assertNoError(
    await supabase
      .from('deposits')
      .update({
        source: body.source === undefined ? existing.source : String(body.source || '').trim(),
        amount: body.amount === undefined ? existing.amount : toInt(body.amount),
        category: body.category === undefined ? existing.category : (body.category || null),
        created_at: body.created_at || existing.created_at
      })
      .eq('id', id)
      .select()
      .single()
  );
}

async function deleteDeposit(supabase, id) {
  assertNoError(await supabase.from('deposits').delete().eq('id', id));
}

module.exports = {
  createDeposit,
  deleteDeposit,
  getDeposit,
  getTotalDeposits,
  listDeposits,
  updateDeposit
};
