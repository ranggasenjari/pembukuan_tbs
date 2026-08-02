const { assertNoError } = require('./base');
const { env } = require('../config/env');

function db(supabase) {
  return typeof supabase.schema === 'function' ? supabase.schema(env.supabaseSchema) : supabase;
}

function text(value) {
  return String(value || '').trim().toUpperCase();
}

function array(value) {
  return value === undefined || value === null ? [] : Array.isArray(value) ? value : [value];
}

function serializeFactory(body) {
  return { name: text(body.name), address: text(body.address) || null, updated_at: new Date().toISOString() };
}

function serializeSpsi(body, factoryId) {
  const names = array(body.spsi_name);
  const modes = array(body.spsi_mode);
  const amounts = array(body.spsi_amount);
  return names.map((name, index) => ({
    factory_id: factoryId,
    name: text(name),
    calculation_mode: modes[index] === 'FIX' ? 'FIX' : 'PER_KG',
    amount: Number(amounts[index] || 0),
    updated_at: new Date().toISOString()
  })).filter((item) => item.name);
}

function serializePrices(body, factoryId) {
  const names = array(body.price_name);
  const prices = array(body.price_value);
  const defaults = array(body.price_default);
  return names.map((name, index) => ({
    factory_id: factoryId,
    name: text(name),
    price: Number(prices[index] || 0),
    is_default: defaults[index] === '1' || defaults[index] === true,
    updated_at: new Date().toISOString()
  })).filter((item) => item.name && item.price > 0);
}

async function listFactories(supabase) {
  return assertNoError(await db(supabase).from('factories').select('*, factory_spsi_types(*), factory_prices(*)').order('name'));
}

async function getFactory(supabase, id) {
  return assertNoError(await db(supabase).from('factories').select('*, factory_spsi_types(*), factory_prices(*)').eq('id', id).single());
}

async function saveTypes(supabase, factoryId, body) {
  const formTypes = serializeSpsi(body, factoryId);
  const existing = assertNoError(
    await db(supabase).from('factory_spsi_types').select('id, name').eq('factory_id', factoryId)
  );
  const existingByName = {};
  existing.forEach(t => { existingByName[t.name] = t.id; });

  for (const t of formTypes) {
    if (existingByName[t.name]) {
      assertNoError(await db(supabase).from('factory_spsi_types').update(t).eq('id', existingByName[t.name]));
    } else {
      assertNoError(await db(supabase).from('factory_spsi_types').insert(t));
    }
  }
}

async function savePrices(supabase, factoryId, body) {
  const formPrices = serializePrices(body, factoryId);
  const existing = assertNoError(
    await db(supabase).from('factory_prices').select('id, name').eq('factory_id', factoryId)
  );
  const existingByName = {};
  existing.forEach(p => { existingByName[p.name] = p.id; });

  for (const p of formPrices) {
    if (existingByName[p.name]) {
      assertNoError(await db(supabase).from('factory_prices').update(p).eq('id', existingByName[p.name]));
    } else {
      assertNoError(await db(supabase).from('factory_prices').insert(p));
    }
  }

  // Hapus harga yang tidak ada di form
  const toRemove = existing.filter(p => !formPrices.some(fp => fp.name === p.name)).map(p => p.id);
  if (toRemove.length) {
    assertNoError(await db(supabase).from('factory_prices').delete().in('id', toRemove));
  }
}

async function createFactory(supabase, body) {
  const factory = serializeFactory(body);
  if (!factory.name) throw new Error('Nama Pabrik wajib diisi.');
  const created = assertNoError(await db(supabase).from('factories').insert(factory).select().single());
  await saveTypes(supabase, created.id, body);
  await savePrices(supabase, created.id, body);
  return getFactory(supabase, created.id);
}

async function updateFactory(supabase, id, body) {
  const factory = serializeFactory(body);
  if (!factory.name) throw new Error('Nama Pabrik wajib diisi.');
  assertNoError(await db(supabase).from('factories').update(factory).eq('id', id));
  await saveTypes(supabase, id, body);
  await savePrices(supabase, id, body);
  return getFactory(supabase, id);
}

async function deleteFactory(supabase, id) {
  assertNoError(await db(supabase).from('factories').delete().eq('id', id));
}

async function getDefaultPrice(supabase, factoryId) {
  if (!factoryId) return null;
  const { data, error } = await supabase
    .from('factory_prices')
    .select('price')
    .eq('factory_id', factoryId)
    .eq('is_default', true)
    .maybeSingle();
  if (error) throw error;
  return data?.price || null;
}

module.exports = { createFactory, deleteFactory, getDefaultPrice, getFactory, listFactories, updateFactory };
