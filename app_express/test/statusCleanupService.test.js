const { normalizeLegacyNotaStatuses } = require('../src/services/statusCleanupService');

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

describe('legacy nota status cleanup', () => {
  it('normalizes legacy BELUM_DIBAYAR nota with items and no payment', async () => {
    const supabase = new FakeSupabase({
      notas: [{ id: 'nota-1', status: 'BELUM_DIBAYAR' }],
      nota_items: [{ invoice_id: 'nota-1', bon_id: 'bon-1' }],
      payments: [],
      bons: [{ id: 'bon-1', status: 'BELUM_DIBAYAR' }]
    });

    const summary = await normalizeLegacyNotaStatuses(supabase, { dryRun: false });

    expect(summary).toMatchObject({
      dryRun: false,
      scanned: 1,
      candidateNotas: 1,
      candidateBons: 1,
      normalizedNotas: 1,
      normalizedBons: 1
    });
    expect(supabase.tables.notas[0].status).toBe('TERTAGIH');
    expect(supabase.tables.bons[0].status).toBe('TERTAGIH');
  });

  it('does not change LUNAS notes or lower LUNAS bons', async () => {
    const supabase = new FakeSupabase({
      notas: [
        { id: 'nota-1', status: 'BELUM_DIBAYAR' },
        { id: 'nota-2', status: 'LUNAS' }
      ],
      nota_items: [
        { invoice_id: 'nota-1', bon_id: 'bon-1' },
        { invoice_id: 'nota-2', bon_id: 'bon-2' }
      ],
      payments: [],
      bons: [
        { id: 'bon-1', status: 'LUNAS' },
        { id: 'bon-2', status: 'LUNAS' }
      ]
    });

    const summary = await normalizeLegacyNotaStatuses(supabase, { dryRun: false });

    expect(summary.scanned).toBe(1);
    expect(summary.candidateNotas).toBe(1);
    expect(summary.candidateBons).toBe(0);
    expect(summary.normalizedNotas).toBe(1);
    expect(summary.normalizedBons).toBe(0);
    expect(supabase.tables.notas.find((nota) => nota.id === 'nota-1').status).toBe('TERTAGIH');
    expect(supabase.tables.notas.find((nota) => nota.id === 'nota-2').status).toBe('LUNAS');
    expect(supabase.tables.bons.map((bon) => bon.status)).toEqual(['LUNAS', 'LUNAS']);
  });

  it('skips legacy notas without items or with payments', async () => {
    const supabase = new FakeSupabase({
      notas: [
        { id: 'nota-1', status: 'BELUM_DIBAYAR' },
        { id: 'nota-2', status: 'BELUM_DIBAYAR' }
      ],
      nota_items: [{ invoice_id: 'nota-2', bon_id: 'bon-2' }],
      payments: [{ id: 'pay-1', invoice_id: 'nota-2' }],
      bons: [{ id: 'bon-2', status: 'BELUM_DIBAYAR' }]
    });

    const summary = await normalizeLegacyNotaStatuses(supabase, { dryRun: false });

    expect(summary).toMatchObject({
      candidateNotas: 0,
      candidateBons: 0,
      normalizedNotas: 0,
      normalizedBons: 0,
      skippedNoItems: 1,
      skippedWithPayments: 1
    });
    expect(supabase.tables.notas.map((nota) => nota.status)).toEqual(['BELUM_DIBAYAR', 'BELUM_DIBAYAR']);
    expect(supabase.tables.bons[0].status).toBe('BELUM_DIBAYAR');
  });

  it('keeps dry-run from writing changes', async () => {
    const supabase = new FakeSupabase({
      notas: [{ id: 'nota-1', status: 'BELUM_DIBAYAR' }],
      nota_items: [{ invoice_id: 'nota-1', bon_id: 'bon-1' }],
      payments: [],
      bons: [{ id: 'bon-1', status: 'BELUM_DIBAYAR' }]
    });

    const summary = await normalizeLegacyNotaStatuses(supabase);

    expect(summary.dryRun).toBe(true);
    expect(summary.candidateNotas).toBe(1);
    expect(summary.candidateBons).toBe(1);
    expect(summary.normalizedNotas).toBe(0);
    expect(summary.normalizedBons).toBe(0);
    expect(supabase.tables.notas[0].status).toBe('BELUM_DIBAYAR');
    expect(supabase.tables.bons[0].status).toBe('BELUM_DIBAYAR');
  });
});
