const { assertNoError } = require('./base');

async function getSummary(supabase, sinceDate) {
  const [expenses, bons, payments, margins] = await Promise.all([
    supabase.from('expenses').select('amount').gte('expense_date', sinceDate),
    supabase.from('bons').select('netto_1, netto_2').gte('bon_date', sinceDate),
    supabase.from('payments').select('amount_paid').gte('payment_date', sinceDate),
    supabase.from('margins').select('margin_amount').gte('transaction_date', sinceDate)
  ]);

  const bonsData = assertNoError(bons);
  const paymentsData = assertNoError(payments);
  const expensesData = assertNoError(expenses);
  const marginsData = assertNoError(margins);

  return {
    totalWeight: bonsData.reduce((sum, bon) => sum + (Number(bon.netto_2) || Number(bon.netto_1) || 0), 0) / 1000,
    totalPayment: paymentsData.reduce((sum, payment) => sum + Number(payment.amount_paid || 0), 0),
    totalExp: expensesData.reduce((sum, expense) => sum + Number(expense.amount || 0), 0),
    totalNetProfit:
      marginsData.reduce((sum, margin) => sum + Number(margin.margin_amount || 0), 0) -
      expensesData.reduce((sum, expense) => sum + Number(expense.amount || 0), 0)
  };
}

async function getLedger(supabase, filters = {}) {
  let marginQuery = supabase
    .from('margins')
    .select(`
      *,
      payments (
        *,
        notas (
          *,
          nota_items (
            bons (*, bon_deductions(*))
          )
        )
      ),
      expense_margins (
        expenses (*)
      )
    `)
    .order('transaction_date', { ascending: false });

  if (filters.start) marginQuery = marginQuery.gte('transaction_date', filters.start);
  if (filters.end) marginQuery = marginQuery.lte('transaction_date', `${filters.end}T23:59:59`);

  const margins = assertNoError(await marginQuery);

  const inProgressBons = assertNoError(
    await supabase
      .from('bons')
      .select(`
        *,
        bon_deductions(*),
        nota_items (
          notas (
            *,
            payments (*)
          )
        )
      `)
      .order('bon_date', { ascending: false })
  );

  const inProgress = inProgressBons.filter((bon) => {
    const notaItem = bon.nota_items && bon.nota_items[0];
    if (!notaItem) return true;
    const nota = notaItem.notas;
    if (!nota) return true;
    const payments = nota.payments || [];
    if (payments.length === 0) return true;
    return payments.every((payment) => !payment.margin_id);
  });

  return { margins, inProgress };
}

module.exports = { getLedger, getSummary };
