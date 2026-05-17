const { assertNoError } = require('./base');
const { getCurrentBalance } = require('./paymentRepository');

function rangeQuery(query, column, start, end) {
  const endDate = new Date(`${end}T00:00:00`);
  endDate.setDate(endDate.getDate() + 1);
  return query.gte(column, start).lt(column, endDate.toISOString().slice(0, 10));
}

async function getDashboardStats(supabase, start, end) {
  const [bons, notas, payments, margins, expenses] = await Promise.all([
    rangeQuery(supabase.from('bons').select('id,status'), 'bon_date', start, end),
    rangeQuery(supabase.from('notas').select('id,status'), 'invoice_date', start, end),
    rangeQuery(supabase.from('payments').select('amount_paid'), 'payment_date', start, end),
    rangeQuery(supabase.from('margins').select('offtaker_amount'), 'transaction_date', start, end),
    rangeQuery(supabase.from('expenses').select('amount'), 'expense_date', start, end)
  ]);

  const bonsData = assertNoError(bons);
  const notasData = assertNoError(notas);
  const paymentsData = assertNoError(payments);
  const marginsData = assertNoError(margins);
  const expensesData = assertNoError(expenses);

  const totalMyTransactions = paymentsData.reduce((sum, row) => sum + Number(row.amount_paid || 0), 0);
  const totalTransactions = marginsData.reduce((sum, row) => sum + Number(row.offtaker_amount || 0), 0);
  const totalMargin = totalTransactions - totalMyTransactions;
  const totalExpenses = expensesData.reduce((sum, row) => sum + Number(row.amount || 0), 0);

  return {
    totalBons: bonsData.length,
    ongoingBons: bonsData.filter((row) => row.status !== 'LUNAS').length,
    finishedBons: bonsData.filter((row) => row.status === 'LUNAS').length,
    unpaidNotas: notasData.filter((row) => row.status !== 'LUNAS').length,
    paidNotas: notasData.filter((row) => row.status === 'LUNAS').length,
    totalTransactions,
    totalMyTransactions,
    totalMargin,
    totalExpenses,
    netProfit: totalMargin - totalExpenses,
    currentBalance: await getCurrentBalance(supabase)
  };
}

module.exports = { getDashboardStats };
