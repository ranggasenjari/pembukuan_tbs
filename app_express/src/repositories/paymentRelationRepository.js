const { assertNoError } = require('./base');
const { env } = require('../config/env');

function db(supabase) {
  return typeof supabase.schema === 'function' ? supabase.schema(env.supabaseSchema) : supabase;
}

function cleanText(value) {
  return String(value || '').trim().toUpperCase();
}

function cleanRaw(value) {
  return String(value || '').trim();
}

function arrayField(value) {
  if (value === undefined || value === null) return [];
  return Array.isArray(value) ? value : [value];
}

function serializePaymentRelation(body) {
  return {
    name: cleanText(body.name),
    contact: cleanRaw(body.contact) || null,
    address: cleanText(body.address) || null,
    notes: cleanRaw(body.notes) || null,
    updated_at: new Date().toISOString()
  };
}

function serializeAccounts(body, paymentRelationId) {
  const bankNames = arrayField(body.bank_name);
  const accountNumbers = arrayField(body.account_number);
  const accountNames = arrayField(body.account_name);

  return bankNames
    .map((bankName, index) => ({
      payment_relation_id: paymentRelationId,
      bank_name: cleanText(bankName),
      account_number: cleanRaw(accountNumbers[index]),
      account_name: cleanText(accountNames[index])
    }))
    .filter((account) => account.bank_name || account.account_number || account.account_name);
}

function vehicleIdsFromBody(body) {
  return arrayField(body.vehicle_ids || body.vehicle_id)
    .map((id) => cleanRaw(id))
    .filter(Boolean);
}

async function findByPlate(supabase, plate) {
  const normalized = String(plate || '').replace(/\s+/g, '').toUpperCase();
  if (!normalized) return null;
  const { data, error } = await db(supabase)
    .from('payment_relation_vehicles')
    .select('payment_relation_id, vehicles!inner(plate_number)')
    .eq('vehicles.plate_number', normalized)
    .maybeSingle();
  if (error) throw error;
  if (!data) return null;
  return getPaymentRelation(supabase, data.payment_relation_id);
}

async function listPaymentRelations(supabase, filters = {}) {
  let query = db(supabase)
    .from('payment_relations')
    .select('*, payment_relation_accounts(*), payment_relation_vehicles(*, vehicles(*))');

  if (filters.q) {
    const q = String(filters.q).trim();
    query = query.or(`name.ilike.%${q}%,address.ilike.%${q}%,contact.ilike.%${q}%`);
  }

  return assertNoError(await query.order('name', { ascending: true }));
}

async function getPaymentRelation(supabase, id) {
  return assertNoError(
    await db(supabase)
      .from('payment_relations')
      .select('*, payment_relation_accounts(*), payment_relation_vehicles(*, vehicles(*))')
      .eq('id', id)
      .single()
  );
}

async function createPaymentRelation(supabase, body) {
  const data = serializePaymentRelation(body);
  if (!data.name) throw new Error('Nama Relasi Bayar wajib diisi.');

  const paymentRelation = assertNoError(
    await db(supabase).from('payment_relations').insert(data).select().single()
  );

  await replaceChildren(supabase, paymentRelation.id, body);
  return getPaymentRelation(supabase, paymentRelation.id);
}

async function bindVehicle(supabase, paymentRelationId, vehicleId) {
  if (!paymentRelationId || !vehicleId) throw new Error('Relasi Bayar dan kendaraan wajib diisi.');
  assertNoError(await db(supabase).from('payment_relation_vehicles').delete().eq('vehicle_id', vehicleId));
  return assertNoError(
    await db(supabase)
      .from('payment_relation_vehicles')
      .insert({ payment_relation_id: paymentRelationId, vehicle_id: vehicleId })
      .select()
      .single()
  );
}

async function updatePaymentRelation(supabase, id, body) {
  const data = serializePaymentRelation(body);
  if (!data.name) throw new Error('Nama Relasi Bayar wajib diisi.');

  assertNoError(await db(supabase).from('payment_relations').update(data).eq('id', id));
  await replaceChildren(supabase, id, body);
  return getPaymentRelation(supabase, id);
}

async function replaceChildren(supabase, paymentRelationId, body) {
  assertNoError(
    await db(supabase).from('payment_relation_accounts').delete().eq('payment_relation_id', paymentRelationId)
  );
  assertNoError(
    await db(supabase).from('payment_relation_vehicles').delete().eq('payment_relation_id', paymentRelationId)
  );

  const accounts = serializeAccounts(body, paymentRelationId);
  if (accounts.length) {
    assertNoError(await db(supabase).from('payment_relation_accounts').insert(accounts));
  }

  const vehicleRows = vehicleIdsFromBody(body).map((vehicleId) => ({
    payment_relation_id: paymentRelationId,
    vehicle_id: vehicleId
  }));
  if (vehicleRows.length) {
    assertNoError(await db(supabase).from('payment_relation_vehicles').insert(vehicleRows));
  }
}

async function deletePaymentRelation(supabase, id) {
  assertNoError(await db(supabase).from('payment_relation_accounts').delete().eq('payment_relation_id', id));
  assertNoError(await db(supabase).from('payment_relation_vehicles').delete().eq('payment_relation_id', id));
  assertNoError(await db(supabase).from('payment_relations').delete().eq('id', id));
}

module.exports = {
  bindVehicle,
  createPaymentRelation,
  deletePaymentRelation,
  findByPlate,
  getPaymentRelation,
  listPaymentRelations,
  updatePaymentRelation
};
