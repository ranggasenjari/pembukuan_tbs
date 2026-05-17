const paymentRepository = require('../src/repositories/paymentRepository');

class FakeBuilder {
  constructor(db, table) {
    this.db = db;
    this.table = table;
    this.operation = 'select';
    this.payload = null;
    this.filters = [];
  }

  select() {
    this.operation = 'select';
    return this;
  }

  update(payload) {
    this.operation = 'update';
    this.payload = payload;
    return this;
  }

  delete() {
    this.operation = 'delete';
    return this;
  }

  eq(column, value) {
    this.filters.push((row) => row[column] === value);
    return this;
  }

  in(column, values) {
    this.filters.push((row) => values.includes(row[column]));
    return this;
  }

  single() {
    return this.execute().then((result) => ({ data: result.data[0] || null, error: result.error }));
  }

  then(resolve, reject) {
    return this.execute().then(resolve, reject);
  }

  async execute() {
    const rows = this.db.tables[this.table];
    const matches = rows.filter((row) => this.filters.every((filter) => filter(row)));

    if (this.operation === 'delete') {
      this.db.tables[this.table] = rows.filter((row) => !matches.includes(row));
      return { data: matches, error: null };
    }

    if (this.operation === 'update') {
      matches.forEach((row) => Object.assign(row, this.payload));
      return { data: matches, error: null };
    }

    return { data: matches, error: null };
  }
}

class FakeSupabase {
  constructor(tables) {
    this.tables = tables;
  }

  from(table) {
    return new FakeBuilder(this, table);
  }
}

describe('paymentRepository status transitions', () => {
  it('returns nota and related bons to TERTAGIH when payment is deleted', async () => {
    const supabase = new FakeSupabase({
      payments: [{ id: 'pay-1', invoice_id: 'nota-1', amount_paid: 1000, margin_id: null }],
      notas: [{ id: 'nota-1', status: 'LUNAS' }],
      nota_items: [
        { invoice_id: 'nota-1', bon_id: 'bon-1' },
        { invoice_id: 'nota-1', bon_id: 'bon-2' }
      ],
      bons: [
        { id: 'bon-1', status: 'LUNAS' },
        { id: 'bon-2', status: 'LUNAS' }
      ]
    });

    await paymentRepository.deletePayment(supabase, 'pay-1');

    expect(supabase.tables.payments).toEqual([]);
    expect(supabase.tables.notas[0].status).toBe('TERTAGIH');
    expect(supabase.tables.bons.map((bon) => bon.status)).toEqual(['TERTAGIH', 'TERTAGIH']);
  });

  it('blocks deletion when payment already belongs to margin', async () => {
    const supabase = new FakeSupabase({
      payments: [{ id: 'pay-1', invoice_id: 'nota-1', amount_paid: 1000, margin_id: 'margin-1' }],
      notas: [{ id: 'nota-1', status: 'LUNAS' }],
      nota_items: [],
      bons: []
    });

    await expect(paymentRepository.deletePayment(supabase, 'pay-1')).rejects.toThrow('margin');
  });
});
