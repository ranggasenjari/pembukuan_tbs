function assertNoError(result, fallbackMessage = 'Database operation failed') {
  if (result.error) {
    const error = new Error(result.error.message || fallbackMessage);
    error.details = result.error;
    throw error;
  }
  return result.data;
}

function nextDayString(dateStr) {
  const [y, m, d] = dateStr.split('-').map(Number);
  const date = new Date(y, m - 1, d);
  date.setDate(date.getDate() + 1);
  return [
    date.getFullYear(),
    String(date.getMonth() + 1).padStart(2, '0'),
    String(date.getDate()).padStart(2, '0')
  ].join('-');
}

function applyDateRange(query, column, startDate, endDate) {
  let next = query;
  if (startDate) next = next.gte(column, startDate);
  if (endDate) next = next.lt(column, nextDayString(endDate));
  return next;
}

module.exports = { applyDateRange, assertNoError };
