const { applyDateRange, assertNoError } = require('./base');
const { toInt } = require('../services/calculations');
const depositRepository = require('./depositRepository');

async function listExpenses(supabase, filters = {}) {
  let query = supabase.from('expenses').select();
  query = applyDateRange(query, 'expense_date', filters.start, filters.end);
  return assertNoError(await query.order('expense_date', { ascending: false }));
}

async function getExpense(supabase, id) {
  return assertNoError(await supabase.from('expenses').select().eq('id', id).single());
}

async function getRelatedMargins(supabase, expenseId) {
  const rows = assertNoError(
    await supabase.from('expense_margins').select('margins(*)').eq('expense_id', expenseId)
  );
  return rows.map((row) => row.margins).filter(Boolean);
}

async function createExpense(supabase, body, marginIds) {
  if (!marginIds.length) throw new Error('Pilih minimal satu data profit/margin.');
  const margins = assertNoError(await supabase.from('margins').select('id,margin_amount').in('id', marginIds));
  const selectedProfit = margins.reduce((sum, margin) => sum + toInt(margin.margin_amount), 0);
  const amount = body.amount === undefined ? toInt(existing.amount) : toInt(body.amount);
  if (amount > selectedProfit) throw new Error('Jumlah melebihi total profit yang dipilih.');

  const expense = assertNoError(
    await supabase
      .from('expenses')
      .insert({
        expense_date: body.expense_date || new Date().toISOString(),
        recipient_name: String(body.recipient_name || '').trim(),
        category: body.category || 'MITRA',
        amount
      })
      .select()
      .single()
  );

  assertNoError(
    await supabase.from('expense_margins').insert(
      marginIds.map((marginId) => ({ expense_id: expense.id, margin_id: marginId }))
    )
  );

  if (body.category === 'DEPOSIT (SALDO)') {
    await depositRepository.createDeposit(supabase, {
      source: 'Deposit dari profit',
      amount,
      category: 'kredit',
      created_at: new Date().toISOString()
    });
  }

  return expense;
}

async function updateExpense(supabase, id, body, marginIds) {
  if (!marginIds.length) throw new Error('Pilih minimal satu data profit/margin.');
  const existing = await getExpense(supabase, id);
  const margins = assertNoError(await supabase.from('margins').select('id,margin_amount').in('id', marginIds));
  const selectedProfit = margins.reduce((sum, margin) => sum + toInt(margin.margin_amount), 0);
  const amount = toInt(body.amount);
  if (amount > selectedProfit) throw new Error('Jumlah melebihi total profit yang dipilih.');

  const expense = assertNoError(
    await supabase
      .from('expenses')
      .update({
        expense_date: body.expense_date || existing.expense_date,
        recipient_name: body.recipient_name === undefined
          ? existing.recipient_name
          : String(body.recipient_name || '').trim(),
        category: body.category === undefined ? (existing.category || 'MITRA') : (body.category || 'MITRA'),
        amount
      })
      .eq('id', id)
      .select()
      .single()
  );

  assertNoError(await supabase.from('expense_margins').delete().eq('expense_id', id));
  assertNoError(
    await supabase.from('expense_margins').insert(
      marginIds.map((marginId) => ({ expense_id: id, margin_id: marginId }))
    )
  );

  if (existing.category !== 'DEPOSIT (SALDO)' && expense.category === 'DEPOSIT (SALDO)') {
    await depositRepository.createDeposit(supabase, {
      source: 'Deposit dari profit',
      amount,
      category: 'kredit',
      created_at: new Date().toISOString()
    });
  }

  return expense;
}

async function deleteExpense(supabase, id) {
  assertNoError(await supabase.from('expense_margins').delete().eq('expense_id', id));
  assertNoError(await supabase.from('expenses').delete().eq('id', id));
}

module.exports = {
  createExpense,
  deleteExpense,
  getExpense,
  getRelatedMargins,
  listExpenses,
  updateExpense
};
