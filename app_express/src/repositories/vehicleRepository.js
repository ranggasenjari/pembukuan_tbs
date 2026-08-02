const { assertNoError } = require('./base');

function text(value) {
  return String(value || '').trim().toUpperCase();
}

function serialize(body) {
  return {
    plate_number: text(body.plate_number),
    driver_name: body.driver_name ? text(body.driver_name) : null,
    potongan_bp: Number(body.potongan_bp ?? 100000),
    harga: body.harga !== undefined && body.harga !== '' ? Number(body.harga) : null,
    is_super: body.is_super === '1' || body.is_super === true,
    updated_at: new Date().toISOString()
  };
}

async function list(supabase) {
  return assertNoError(await supabase.from('vehicles').select('*').order('plate_number'));
}

async function get(supabase, id) {
  return assertNoError(await supabase.from('vehicles').select('*').eq('id', id).single());
}

async function getByPlate(supabase, plate) {
  const { data, error } = await supabase
    .from('vehicles')
    .select('*')
    .eq('plate_number', text(plate))
    .maybeSingle();
  return assertNoError({ data, error });
}

async function create(supabase, body) {
  const record = serialize(body);
  if (!record.plate_number) throw new Error('Plat nomor wajib diisi.');
  const created = assertNoError(await supabase.from('vehicles').insert(record).select().single());
  return created;
}

async function update(supabase, id, body) {
  const record = serialize(body);
  if (!record.plate_number) throw new Error('Plat nomor wajib diisi.');
  assertNoError(await supabase.from('vehicles').update(record).eq('id', id));
  return get(supabase, id);
}

async function remove(supabase, id) {
  assertNoError(await supabase.from('vehicles').delete().eq('id', id));
}

async function getPlateMap(supabase) {
  const rows = await list(supabase);
  const map = {};
  rows.forEach(v => { map[v.plate_number] = { potongan_bp: v.potongan_bp, harga: v.harga }; });
  return map;
}

async function listEnriched(supabase) {
  const vehicles = await list(supabase);

  const { data: bons } = await supabase
    .from('bons')
    .select('plate_number, driver_name, relation_agents(name), factories(name)')
    .not('plate_number', 'is', null)
    .neq('plate_number', '');

  const agg = {};
  (bons || []).forEach(b => {
    const plate = text(b.plate_number);
    if (!plate) return;
    if (!agg[plate]) agg[plate] = { drivers: new Set(), relations: new Set(), factories: new Set() };
    if (b.driver_name) agg[plate].drivers.add(b.driver_name.replace(/\s+/g, ' ').trim().toUpperCase());
    if (b.relation_agents?.name) agg[plate].relations.add(b.relation_agents.name);
    if (b.factories?.name) agg[plate].factories.add(b.factories.name);
  });

  return vehicles.map(v => ({
    ...v,
    driver_list: [...(agg[v.plate_number]?.drivers || [])].sort(),
    relation_list: [...(agg[v.plate_number]?.relations || [])].sort(),
    factory_list: [...(agg[v.plate_number]?.factories || [])].sort()
  }));
}

module.exports = { list, listEnriched, get, getByPlate, create, update, remove, getPlateMap };
