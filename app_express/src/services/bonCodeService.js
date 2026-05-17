const { apiError } = require('./apiResponse');
const { arrayField } = require('./request');

function normalizeCodes(value) {
  return [...new Set(arrayField(value).map((code) => String(code).trim()).filter(Boolean))];
}

async function findBonByTicketNumber(supabase, ticketNumber) {
  const { data, error } = await supabase
    .from('bons')
    .select('id,ticket_number,status,total')
    .eq('ticket_number', ticketNumber);

  if (error) throw error;
  if (!data || data.length === 0) {
    throw apiError(404, 'BON_CODE_NOT_FOUND', `Kode bon ${ticketNumber} tidak ditemukan.`);
  }
  if (data.length > 1) {
    throw apiError(409, 'BON_CODE_DUPLICATE', `Kode bon ${ticketNumber} ditemukan lebih dari satu kali.`);
  }
  return data[0];
}

async function resolveBonIdsByTicketNumbers(supabase, bonCodes) {
  const codes = normalizeCodes(bonCodes);
  if (codes.length === 0) {
    throw apiError(400, 'BON_CODES_REQUIRED', 'bon_codes wajib diisi minimal satu kode bon.');
  }

  const bons = [];
  for (const code of codes) {
    bons.push(await findBonByTicketNumber(supabase, code));
  }

  return {
    bons,
    bonIds: bons.map((bon) => bon.id)
  };
}

module.exports = { findBonByTicketNumber, normalizeCodes, resolveBonIdsByTicketNumbers };
