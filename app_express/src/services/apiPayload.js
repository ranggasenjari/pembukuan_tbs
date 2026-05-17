const { parseDeductions, toInt } = require('./calculations');
const { arrayField } = require('./request');

function normalizeDeductions(body) {
  if (Array.isArray(body.deductions)) {
    return body.deductions
      .map((item) => ({
        label: String(item?.label || item?.name || '').trim(),
        amount: toInt(item?.amount)
      }))
      .filter((item) => item.label || item.amount !== 0);
  }

  return parseDeductions(body);
}

function idsFromBody(body, field) {
  return arrayField(body[field]).map((id) => String(id).trim()).filter(Boolean);
}

module.exports = { idsFromBody, normalizeDeductions };
