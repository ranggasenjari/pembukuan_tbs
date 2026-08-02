const { settleAllNotas } = require('../src/services/notaSettlementService');

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

  insert(payload) {
    this.operation = 'insert';
    this.payload = payload;
    return this;
  }

  update(payload) {
    this.operation = 'update';
    this.payload = payload;
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

  then(resolve, reject) {
    return this.execute().then(resolve, reject);
  }

  async execute() {
    const rows = this.db.tables[this.table] || [];
    const matches = rows.filter((row) => this.filters.every((filter) => filter(row)));

    if (this.operation === 'insert') {
      const payloads = Array.isArray(this.payload) ? this.payload : [this.payload];
      const inserted = payloads.map((payload, index) => ({
        id: payload.id || `${this.table}-${rows.length + index + 1}`,
        ...payload
      }));
      rows.push(...inserted);
      this.db.tables[this.table] = rows;
      return { data: inserted, error: null };
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

describe('nota settlement cleanup', () => {
  it('dry-runs outstanding payments without writing rows', async () => {
    const supabase = new FakeSupabase({
      notas: [{ id: 'nota-1', invoice_number: 'N-1', invoice_date: '2026-05-01', total_amount: 1000, status: 'TERTAGIH' }],
      payments: [],
      deposits: [],
      nota_items: [{ invoice_id: 'nota-1', bon_id: 'bon-1' }],
      bons: [{ id: 'bon-1', status: 'TERTAGIH' }]
    });

    const summary = await settleAllNotas(supabase, { paymentDate: '2026-05-28T00:00:00.000Z' });

    expect(summary).toMatchObject({
      dryRun: true,
      scannedNotas: 1,
      payableNotas: 1,
      totalPaymentAmount: 1000,
      depositCreated: false,
      paymentsCreated: 0
    });
    expect(supabase.tables.payments).toHaveLength(0);
    expect(supabase.tables.deposits).toHaveLength(0);
    expect(supabase.tables.notas[0].status).toBe('TERTAGIH');
  });

  it('creates one deposit, missing payments, and marks notas/bons LUNAS', async () => {
    const supabase = new FakeSupabase({
      notas: [
        { id: 'nota-1', invoice_number: 'N-1', invoice_date: '2026-05-01', total_amount: 1000, status: 'TERTAGIH' },
        { id: 'nota-2', invoice_number: 'N-2', invoice_date: '2026-05-02', total_amount: 700, status: 'BELUM_DIBAYAR' },
        { id: 'nota-3', invoice_number: 'N-3', invoice_date: '2026-05-03', total_amount: 500, status: 'LUNAS' }
      ],
      payments: [
        { id: 'pay-existing', invoice_id: 'nota-2', amount_paid: 200 },
        { id: 'pay-paid', invoice_id: 'nota-3', amount_paid: 500 }
      ],
      deposits: [],
      nota_items: [
        { invoice_id: 'nota-1', bon_id: 'bon-1' },
        { invoice_id: 'nota-2', bon_id: 'bon-2' },
        { invoice_id: 'nota-3', bon_id: 'bon-3' }
      ],
      bons: [
        { id: 'bon-1', status: 'TERTAGIH' },
        { id: 'bon-2', status: 'BELUM_DIBAYAR' },
        { id: 'bon-3', status: 'LUNAS' }
      ]
    });

    const summary = await settleAllNotas(supabase, {
      dryRun: false,
      paymentDate: '2026-05-28T00:00:00.000Z',
      proofUrl: 'https://example.test/proof.jpg'
    });

    expect(summary).toMatchObject({
      dryRun: false,
      payableNotas: 2,
      skippedFullySettled: 1,
      totalPaymentAmount: 1500,
      depositCreated: true,
      paymentsCreated: 2,
      notasMarkedLunas: 2,
      bonsMarkedLunas: 2
    });
    expect(supabase.tables.deposits).toEqual([
      expect.objectContaining({ amount: 1500, category: 'kredit' })
    ]);
    expect(supabase.tables.payments).toEqual(expect.arrayContaining([
      expect.objectContaining({ invoice_id: 'nota-1', amount_paid: 1000, payment_date: '2026-05-01' }),
      expect.objectContaining({ invoice_id: 'nota-2', amount_paid: 500, payment_date: '2026-05-02' })
    ]));
    expect(supabase.tables.notas.map((nota) => nota.status)).toEqual(['LUNAS', 'LUNAS', 'LUNAS']);
    expect(supabase.tables.bons.map((bon) => bon.status)).toEqual(['LUNAS', 'LUNAS', 'LUNAS']);
  });

  it('marks already paid legacy notas LUNAS without adding deposit/payment', async () => {
    const supabase = new FakeSupabase({
      notas: [{ id: 'nota-1', invoice_number: 'N-1', invoice_date: '2026-05-01', total_amount: 1000, status: 'TERTAGIH' }],
      payments: [{ id: 'pay-1', invoice_id: 'nota-1', amount_paid: 1000 }],
      deposits: [],
      nota_items: [{ invoice_id: 'nota-1', bon_id: 'bon-1' }],
      bons: [{ id: 'bon-1', status: 'TERTAGIH' }]
    });

    const summary = await settleAllNotas(supabase, { dryRun: false });

    expect(summary).toMatchObject({
      payableNotas: 0,
      statusOnlyNotas: 1,
      totalPaymentAmount: 0,
      depositCreated: false,
      paymentsCreated: 0,
      notasMarkedLunas: 1,
      bonsMarkedLunas: 1
    });
    expect(supabase.tables.deposits).toHaveLength(0);
    expect(supabase.tables.payments).toHaveLength(1);
    expect(supabase.tables.notas[0].status).toBe('LUNAS');
    expect(supabase.tables.bons[0].status).toBe('LUNAS');
  });
});
