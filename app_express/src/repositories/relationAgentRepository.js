const { assertNoError } = require('./base');
const { env } = require('../config/env');

function db(supabase) {
  return typeof supabase.schema === 'function' ? supabase.schema(env.supabaseSchema) : supabase;
}

function cleanText(value) {
  return String(value || '').trim().toUpperCase();
}

function arrayField(value) {
  if (value === undefined || value === null) return [];
  return Array.isArray(value) ? value : [value];
}

function serializeRelationAgent(body) {
  return {
    name: cleanText(body.name),
    address: cleanText(body.address) || null,
    contact: String(body.contact || '').trim() || null,
    updated_at: new Date().toISOString()
  };
}

function serializeAccounts(body, relationAgentId) {
  const names = arrayField(body.account_name);
  const numbers = arrayField(body.account_number);
  return names
    .map((name, index) => ({
      relation_agent_id: relationAgentId,
      account_name: cleanText(name),
      account_number: String(numbers[index] || '').trim()
    }))
    .filter((account) => account.account_name || account.account_number);
}

async function listRelationAgents(supabase, filters = {}) {
  let query = db(supabase)
    .from('relation_agents')
    .select('*, relation_agent_accounts(*)');

  if (filters.q) {
    const q = String(filters.q).trim();
    query = query.or(`name.ilike.%${q}%,address.ilike.%${q}%,contact.ilike.%${q}%`);
  }

  return assertNoError(await query.order('name', { ascending: true }));
}

async function getRelationAgent(supabase, id) {
  return assertNoError(
    await db(supabase)
      .from('relation_agents')
      .select('*, relation_agent_accounts(*)')
      .eq('id', id)
      .single()
  );
}

async function createRelationAgent(supabase, body) {
  const data = serializeRelationAgent(body);
  if (!data.name) throw new Error('Nama Relasi / Agen wajib diisi.');

  const relationAgent = assertNoError(
    await db(supabase).from('relation_agents').insert(data).select().single()
  );

  await replaceAccounts(supabase, relationAgent.id, body);
  return getRelationAgent(supabase, relationAgent.id);
}

async function updateRelationAgent(supabase, id, body) {
  const data = serializeRelationAgent(body);
  if (!data.name) throw new Error('Nama Relasi / Agen wajib diisi.');

  assertNoError(await db(supabase).from('relation_agents').update(data).eq('id', id));
  await replaceAccounts(supabase, id, body);
  return getRelationAgent(supabase, id);
}

async function replaceAccounts(supabase, relationAgentId, body) {
  assertNoError(
    await db(supabase).from('relation_agent_accounts').delete().eq('relation_agent_id', relationAgentId)
  );
  const accounts = serializeAccounts(body, relationAgentId);
  if (accounts.length) {
    assertNoError(await db(supabase).from('relation_agent_accounts').insert(accounts));
  }
}

async function deleteRelationAgent(supabase, id) {
  assertNoError(await db(supabase).from('relation_agent_accounts').delete().eq('relation_agent_id', id));
  assertNoError(await db(supabase).from('relation_agents').delete().eq('id', id));
}

module.exports = {
  createRelationAgent,
  deleteRelationAgent,
  getRelationAgent,
  listRelationAgents,
  updateRelationAgent
};
