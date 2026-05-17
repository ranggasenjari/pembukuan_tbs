function assertNoError(result, fallbackMessage = 'Database operation failed') {
  if (result.error) {
    const error = new Error(result.error.message || fallbackMessage);
    error.details = result.error;
    throw error;
  }
  return result.data;
}

function applyDateRange(query, column, startDate, endDate) {
  let next = query;
  if (startDate) next = next.gte(column, startDate);
  if (endDate) {
    const end = new Date(`${endDate}T00:00:00`);
    end.setDate(end.getDate() + 1);
    next = next.lt(column, end.toISOString().slice(0, 10));
  }
  return next;
}

module.exports = { applyDateRange, assertNoError };
