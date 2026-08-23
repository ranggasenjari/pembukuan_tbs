const bonRepository = require('../repositories/bonRepository');
const factoryRepository = require('../repositories/factoryRepository');
const relationAgentRepository = require('../repositories/relationAgentRepository');
const { calculateBon, parseDeductions, PAYMENT_STATUS } = require('./calculations');

function cleanBody(body) {
  return Object.fromEntries(
    Object.entries(body || {}).filter(([, value]) => value !== '' && value !== undefined)
  );
}

async function applyManagedBonUpdate(supabase, bonId, requestBody) {
  requestBody = requestBody || {};
  const current = await bonRepository.getBon(supabase, bonId);
  if (current.status === PAYMENT_STATUS.LUNAS) {
    throw new Error('Bon sudah lunas, tidak dapat diedit.');
  }

  const body = { ...current, ...cleanBody(requestBody), status: current.status };
  const relationChanged =
    requestBody.relation_agent_id !== undefined || requestBody.new_relation_name !== undefined;

  if (relationChanged) {
    const newRelName = requestBody.new_relation_name ? String(requestBody.new_relation_name).trim() : '';
    const relationAgentId = requestBody.relation_agent_id || null;
    if (newRelName) {
      const created = await relationAgentRepository.createRelationAgent(supabase, {
        name: newRelName,
        address: requestBody.new_relation_address || null
      });
      body.relation_agent_id = created.id;
      body.relation_name = created.name;
    } else if (relationAgentId) {
      const agent = await relationAgentRepository.getRelationAgent(supabase, relationAgentId);
      body.relation_agent_id = agent.id;
      body.relation_name = agent.name;
    } else {
      body.relation_agent_id = null;
    }
  }

  if (body.factory_spsi_type_id && body.factory_id) {
    const factory = await factoryRepository.getFactory(supabase, body.factory_id);
    const type = (factory.factory_spsi_types || []).find((item) => item.id === body.factory_spsi_type_id);
    if (type) {
      body.spsi_type_name = type.name;
      body.spsi_calculation_mode = type.calculation_mode;
      body.spsi_rate = type.amount;
      body.biaya_bongkar = type.amount;
    }
  }

  if (requestBody.pph_enabled !== undefined) {
    const enabled = requestBody.pph_enabled === '1' || requestBody.pph_enabled === 'true' || requestBody.pph_enabled === true;
    body.pph = enabled ? undefined : 0;
  }

  const deductions = parseDeductions(requestBody);
  const calculated = calculateBon({ ...body, deductions });
  const data = bonRepository.serializeBon(body, calculated, current.image_url);
  await bonRepository.updateBon(supabase, bonId, data, deductions, true);

  if (relationChanged && current.relation_agent_id !== body.relation_agent_id) {
    const related = await bonRepository.getRelatedRecords(supabase, bonId);
    for (const nota of related.notas) {
      await supabase
        .from('notas')
        .update({
          relation_agent_id: body.relation_agent_id || null,
          recipient_name: body.relation_agent_id ? null : (body.relation_name || null),
          recipient_address: body.fruit_origin || null
        })
        .eq('id', nota.id);
    }
  }

  return bonRepository.getBon(supabase, bonId);
}

module.exports = { applyManagedBonUpdate };
