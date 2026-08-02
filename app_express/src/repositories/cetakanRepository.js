const { assertNoError } = require('./base');

async function listCetakan(supabase) {
  const { data, error } = await supabase
    .from('cetakan_history')
    .select('*, factories(name)')
    .order('printed_at', { ascending: false });
  return assertNoError({ data, error });
}

async function createCetakan(supabase, record) {
  const { data, error } = await supabase
    .from('cetakan_history')
    .insert(record)
    .select()
    .single();
  return assertNoError({ data, error });
}

async function getCetakan(supabase, id) {
  const { data, error } = await supabase
    .from('cetakan_history')
    .select('*')
    .eq('id', id)
    .single();
  return assertNoError({ data, error });
}

async function getByDateAndFactory(supabase, date, factoryId) {
  let query = supabase.from('cetakan_history').select('*').eq('date', date);
  if (factoryId) query = query.eq('factory_id', factoryId);
  else query = query.is('factory_id', null);
  const { data, error } = await query.maybeSingle();
  return assertNoError({ data, error });
}

async function upsertCetakan(supabase, record) {
  const existing = await getByDateAndFactory(supabase, record.date, record.factory_id);
  if (existing) {
    const { data, error } = await supabase
      .from('cetakan_history')
      .update({
        total_bons: record.total_bons,
        total_tonase: record.total_tonase,
        total_amount: record.total_amount,
        file_path: record.file_path,
        printed_at: new Date().toISOString()
      })
      .eq('id', existing.id)
      .select()
      .single();
    return assertNoError({ data, error });
  }
  const { data, error } = await supabase
    .from('cetakan_history')
    .insert(record)
    .select()
    .single();
  return assertNoError({ data, error });
}

module.exports = { listCetakan, createCetakan, getCetakan, getByDateAndFactory, upsertCetakan };
