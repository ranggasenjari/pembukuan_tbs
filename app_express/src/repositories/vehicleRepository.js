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
    uang_minum: body.uang_minum !== undefined && body.uang_minum !== '' ? Number(body.uang_minum) : null,
    is_super: body.is_super === '1' || body.is_super === true,
    updated_at: new Date().toISOString()
  };
}

async function list(supabase, filters = {}) {
  let query = supabase.from('vehicles').select('*');
  if (filters.q) {
    const q = String(filters.q).trim();
    query = query.or(`plate_number.ilike.%${q}%,driver_name.ilike.%${q}%`);
  }
  return assertNoError(await query.order('plate_number'));
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

async function listEnriched(supabase, filters = {}) {
  const vehicles = await list(supabase, filters);

  const { data: bons } = await supabase
    .from('bons')
    .select('plate_number, bon_date, netto_2, bp_colt, driver_name, image_url, relation_agents(name), factories(name)')
    .not('plate_number', 'is', null)
    .neq('plate_number', '');

  const agg = {};
  (bons || []).forEach(b => {
    const plate = text(b.plate_number);
    if (!plate) return;
    if (!agg[plate]) agg[plate] = { drivers: new Set(), relations: new Set(), factories: new Set(), history: [], latest: '' };
    if (b.driver_name) agg[plate].drivers.add(b.driver_name.replace(/\s+/g, ' ').trim().toUpperCase());
    if (b.relation_agents?.name) agg[plate].relations.add(b.relation_agents.name);
    if (b.factories?.name) agg[plate].factories.add(b.factories.name);
    if (b.bon_date && String(b.bon_date) > agg[plate].latest) agg[plate].latest = String(b.bon_date);
    if (b.netto_2 != null || b.bp_colt != null) {
      agg[plate].history.push({ date: b.bon_date, netto2: b.netto_2, bp: b.bp_colt, factory: b.factories?.name || '', imageUrl: b.image_url || '' });
    }
  });

  // Riwayat netto_2 & BP per plat, terbaru dulu (maksimal 10 entri).
  const historyByPlate = {};
  Object.keys(agg).forEach(plate => {
    historyByPlate[plate] = (agg[plate].history || [])
      .sort((a, b) => String(b.date || '').localeCompare(String(a.date || '')))
      .slice(0, 10)
      .map(h => ({ date: h.date, netto2: h.netto2 ?? 0, bp: h.bp ?? 0, factory: h.factory || '', imageUrl: h.imageUrl || '' }));
  });

  // Relasi bayar yang terikat ke tiap kendaraan (lewat payment_relation_vehicles)
  const { data: relations } = await supabase
    .from('payment_relation_vehicles')
    .select('vehicle_id, payment_relation_id, payment_relations(name)');
  const relationByVehicle = {};
  (relations || []).forEach(r => {
    relationByVehicle[r.vehicle_id] = {
      id: r.payment_relation_id,
      name: r.payment_relations?.name || ''
    };
  });

  const enriched = vehicles.map(v => ({
    ...v,
    driver_list: [...(agg[v.plate_number]?.drivers || [])].sort(),
    relation_list: [...(agg[v.plate_number]?.relations || [])].sort(),
    factory_list: [...(agg[v.plate_number]?.factories || [])].sort(),
    history: historyByPlate[v.plate_number] || [],
    latest_bon_date: agg[v.plate_number]?.latest || '',
    payment_relation_id: relationByVehicle[v.id]?.id || null,
    payment_relation_name: relationByVehicle[v.id]?.name || ''
  }));

  enriched.sort((a, b) => {
    const da = a.latest_bon_date ? String(a.latest_bon_date) : '';
    const db = b.latest_bon_date ? String(b.latest_bon_date) : '';
    if (da && db) return db.localeCompare(da);
    if (da) return -1;
    if (db) return 1;
    return String(a.plate_number || '').localeCompare(String(b.plate_number || ''));
  });

  return enriched;
}

module.exports = { list, listEnriched, get, getByPlate, create, update, remove, getPlateMap };