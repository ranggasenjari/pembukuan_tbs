const { assertNoError } = require('./base');
const { getCurrentBalance } = require('./paymentRepository');

function rangeQuery(query, column, start, end) {
  const endDate = new Date(`${end}T00:00:00`);
  endDate.setDate(endDate.getDate() + 1);
  return query.gte(column, start).lt(column, endDate.toISOString().slice(0, 10));
}

function groupBonsByFactory(bons) {
  const map = new Map();
  for (const row of bons) {
    const factoryId = row.factory_id || null;
    const name = row.factories?.name || 'Tanpa Pabrik';
    const key = factoryId || `__no__${name}`;
    const subTotal = (row.sub_notas || []).reduce((s, n) => s + Number(n.amount || 0), 0);
    let entry = map.get(key);
    if (!entry) {
      entry = { factory_id: factoryId, name, count: 0, tonnage: 0, value: 0 };
      map.set(key, entry);
    }
    entry.count += 1;
    entry.tonnage += Number(row.netto_2 || 0);
    entry.value += Number(row.total || 0) + subTotal;
  }
  return [...map.values()].sort((a, b) => b.tonnage - a.tonnage);
}

async function getDashboardStats(supabase, start, end) {
  const bonsQuery = rangeQuery(
    supabase.from('bons').select('id,status,factory_id,netto_2,total,factories(name),sub_notas(*)'),
    'bon_date',
    start,
    end
  );

  const running = await Promise.all([
    bonsQuery,
    rangeQuery(supabase.from('notas').select('id,status'), 'invoice_date', start, end),
    rangeQuery(supabase.from('payments').select('amount_paid'), 'payment_date', start, end),
    rangeQuery(supabase.from('margins').select('offtaker_amount'), 'transaction_date', start, end),
    rangeQuery(supabase.from('expenses').select('amount'), 'expense_date', start, end)
  ]).catch((error) => {
    // Fallback bila tabel sub_notas belum migrasi
    return Promise.all([
      rangeQuery(supabase.from('bons').select('id,status,factory_id,netto_2,total,factories(name)'), 'bon_date', start, end),
      rangeQuery(supabase.from('notas').select('id,status'), 'invoice_date', start, end),
      rangeQuery(supabase.from('payments').select('amount_paid'), 'payment_date', start, end),
      rangeQuery(supabase.from('margins').select('offtaker_amount'), 'transaction_date', start, end),
      rangeQuery(supabase.from('expenses').select('amount'), 'expense_date', start, end)
    ]);
  });

  const [bons, notas, payments, margins, expenses] = running;

  const bonsData = assertNoError(bons);
  const notasData = assertNoError(notas);
  const paymentsData = assertNoError(payments);
  const marginsData = assertNoError(margins);
  const expensesData = assertNoError(expenses);

  const totalMyTransactions = paymentsData.reduce((sum, row) => sum + Number(row.amount_paid || 0), 0);
  const totalTransactions = marginsData.reduce((sum, row) => sum + Number(row.offtaker_amount || 0), 0);
  const totalMargin = totalTransactions - totalMyTransactions;
  const totalExpenses = expensesData.reduce((sum, row) => sum + Number(row.amount || 0), 0);

  // Fokus transaksi harian
  const totalTonnage = bonsData.reduce((sum, row) => sum + Number(row.netto_2 || 0), 0);
  const totalTransactionValue = bonsData.reduce((sum, row) => {
    const subTotal = (row.sub_notas || []).reduce((s, n) => s + Number(n.amount || 0), 0);
    return sum + Number(row.total || 0) + subTotal;
  }, 0);
  const factoryBreakdown = groupBonsByFactory(bonsData);

  return {
    totalBons: bonsData.length,
    ongoingBons: bonsData.filter((row) => row.status !== 'LUNAS').length,
    finishedBons: bonsData.filter((row) => row.status === 'LUNAS').length,
    unpaidNotas: notasData.filter((row) => row.status !== 'LUNAS').length,
    paidNotas: notasData.filter((row) => row.status === 'LUNAS').length,
    totalTonnage,
    totalTransactionValue,
    totalPayments: totalMyTransactions,
    factoryBreakdown,
    totalTransactions,
    totalMyTransactions,
    totalMargin,
    totalExpenses,
    netProfit: totalMargin - totalExpenses,
    currentBalance: await getCurrentBalance(supabase)
  };
}

module.exports = { getDashboardStats };