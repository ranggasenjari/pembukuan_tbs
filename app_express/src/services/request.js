function arrayField(value) {
  if (value === undefined || value === null) return [];
  return Array.isArray(value) ? value.filter(Boolean) : [value].filter(Boolean);
}

function todayInput() {
  return new Date().toISOString().slice(0, 10);
}

function monthStartInput() {
  const date = new Date();
  return new Date(date.getFullYear(), date.getMonth(), 1).toISOString().slice(0, 10);
}

module.exports = { arrayField, monthStartInput, todayInput };
