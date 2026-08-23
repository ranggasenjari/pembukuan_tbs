const subNotaRepository = require('../src/repositories/subNotaRepository');

class FakeBuilder {
  constructor(tables, table) {
    this.tables = tables;
    this.table = table;
    this.operation = 'select';
    this.payload = null;
    this.filters = [];
    this.pendingSingle = false;
    this.pendingOrder = null;
  }

  select(columns) {
    this.columns = columns;
    return this;
  }

  insert(payload) {
    this.operation = 'insert';
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

  order(column, options) {
    this.pendingOrder = { column, options };
    return this;
  }

  single() {
    this.pendingSingle = true;
    return this;
  }

  then(resolve, reject) {
    return this.execute().then(resolve, reject);
  }

  async execute() {
    const rows = this.tables[this.table] || [];
    let matches = rows.filter((row) => this.filters.every((filter) => filter(row)));

    if (this.pendingOrder) {
      const { column, options } = this.pendingOrder;
      const dir = options && options.ascending === false ? -1 : 1;
      matches = [...matches].sort((a, b) => (a[column] > b[column] ? dir : a[column] < b[column] ? -dir : 0));
    }

    if (this.operation === 'insert') {
      const inserted = { id: 'sub-nota-1', ...this.payload };
      rows.push(inserted);
      this.tables[this.table] = rows;
      if (this.pendingSingle) return { data: inserted, error: null };
      return { data: [inserted], error: null };
    }

    if (this.operation === 'delete') {
      const removed = matches.slice();
      this.tables[this.table] = rows.filter((row) => !matches.includes(row));
      return { data: removed, error: null };
    }

    if (this.pendingSingle) {
      return { data: matches[0] || null, error: null };
    }
    return { data: matches, error: null };
  }
}

class FakeSupabase {
  constructor(tables) {
    this.tables = tables;
  }

  from(table) {
    return new FakeBuilder(this.tables, table);
  }
}

describe('subNotaRepository', () => {
  it('creates sub nota dengan total murni netto_2 x harga dan nama upper', async () => {
    const supabase = new FakeSupabase({
      bons: [{ id: 'bon-1', netto_2: 2500 }],
      sub_notas: []
    });

    const created = await subNotaRepository.createForBon(supabase, 'bon-1', {
      name: 'anu jaya',
      price_per_kg: '40',
      notes: 'Komisi pengangkutan'
    });

    expect(created.name).toBe('ANU JAYA');
    expect(created.price_per_kg).toBe(40);
    expect(created.netto_2).toBe(2500);
    expect(created.amount).toBe(100000);
  });

  it('menolak bila nama kosong atau harga <= 0', async () => {
    const supabase = new FakeSupabase({ bons: [{ id: 'bon-1', netto_2: 100 }], sub_notas: [] });

    await expect(
      subNotaRepository.createForBon(supabase, 'bon-1', { name: ' ', price_per_kg: '40' })
    ).rejects.toThrow('Nama wajib diisi.');

    await expect(
      subNotaRepository.createForBon(supabase, 'bon-1', { name: 'ANU', price_per_kg: '0' })
    ).rejects.toThrow('Harga (Rp/kg) wajib lebih dari 0.');
  });

  it('lists sub notas by bon', async () => {
    const supabase = new FakeSupabase({
      bons: [],
      sub_notas: [
        { id: 's1', bon_id: 'bon-1', name: 'A' },
        { id: 's2', bon_id: 'bon-1', name: 'B' },
        { id: 's3', bon_id: 'bon-2', name: 'C' }
      ]
    });

    const list = await subNotaRepository.listByBon(supabase, 'bon-1');
    expect(list).toHaveLength(2);
    expect(list.map((s) => s.name)).toEqual(['A', 'B']);
  });

  it('deletes sub nota', async () => {
    const supabase = new FakeSupabase({
      bons: [],
      sub_notas: [{ id: 's1', bon_id: 'bon-1', name: 'A' }]
    });

    await subNotaRepository.deleteSubNota(supabase, 's1');
    expect(supabase.tables.sub_notas).toHaveLength(0);
  });
});