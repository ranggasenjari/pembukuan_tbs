const { getDashboardStats } = require('../src/repositories/dashboardRepository');

const { assertNoError } = require('../src/repositories/base');

function makeRows(rows) {
  return { data: rows, error: null };
}

function makeSupabase() {
  const tables = {
    bons: [],
    notas: [],
    payments: [],
    margins: [],
    expenses: [],
    deposits: []
  };
  // Return object supporting a chainable query surface included by getDashboardStats.
  function buildFromTable(name) {
    return {
      select() { return this; },
      gte() { return this; },
      lt() { return this; },
      fields: undefined,
      async then(resolve) {
        const data = tables[name];
        resolve(makeRows(data));
      }
    };
  }
  return {
    tables,
    from(name) {
      const table = buildFromTable(name);
      table.select = () => table;
      return table;
    }
  };
}

describe('dashboardRepository', () => {
  it('computes daily transaction metrics and per-factory breakdown', async () => {
    const supabase = makeSupabase();
    supabase.tables.bons = [
      { id: 'b1', status: 'BELUM_DIBAYAR', factory_id: 'f1', netto_2: 1000, total: 5000000, factories: { name: 'PT A' } },
      { id: 'b2', status: 'BELUM_DIBAYAR', factory_id: 'f2', netto_2: 500, total: 2000000, factories: { name: 'PT B' } },
      { id: 'b3', status: 'LUNAS', factory_id: 'f1', netto_2: 250, total: 1000000, factories: { name: 'PT A' } }
    ];
    supabase.tables.notas = [
      { id: 'n1', status: 'LUNAS' }
    ];
    supabase.tables.payments = [
      { amount_paid: 8000000 }
    ];
    supabase.tables.margins = [
      { offtaker_amount: 10000000 }
    ];
    supabase.tables.expenses = [
      { amount: 500000 }
    ];
    supabase.tables.deposits = [
      { amount: 20000000 }
    ];

    const stats = await getDashboardStats(supabase, '2026-08-01', '2026-08-18');

    expect(stats.totalBons).toBe(3);
    expect(stats.totalTonnage).toBe(1750);
    expect(stats.totalTransactionValue).toBe(8000000);
    expect(stats.totalPayments).toBe(8000000);
    expect(stats.totalMargin).toBe(2000000);
    expect(stats.netProfit).toBe(1500000);

    expect(stats.factoryBreakdown).toHaveLength(2);
    expect(stats.factoryBreakdown[0]).toMatchObject({ name: 'PT A', count: 2, tonnage: 1250, value: 6000000 });
    expect(stats.factoryBreakdown[1]).toMatchObject({ name: 'PT B', count: 1, tonnage: 500, value: 2000000 });
  });
});