const notaRepository = require('../src/repositories/notaRepository');
const marginRepository = require('../src/repositories/marginRepository');
const bonRepository = require('../src/repositories/bonRepository');

class FakeBuilder {
  constructor(db, table) {
    this.db = db;
    this.table = table;
    this.operation = 'select';
    this.payload = null;
    this.filters = [];
  }

  select() {
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

  single() {
    return this.execute().then((result) => ({ data: result.data[0] || null, error: result.error }));
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
        created_at: payload.created_at || '2026-07-18T00:00:00.000Z',
        updated_at: payload.updated_at || '2026-07-18T00:00:00.000Z',
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

describe('master transaction payloads', () => {
  it('serializes Bon master references and SPSI snapshot', () => {
    const data = bonRepository.serializeBon(
      {
        bon_date: '2026-07-18',
        plate_number: 'bk 1234 aa',
        driver_name: 'budi',
        relation_name: 'agen maju',
        relation_agent_id: 'rel-1',
        transport_id: 'transport-1',
        factory_id: 'factory-1',
        factory_spsi_type_id: 'spsi-1',
        spsi_type_name: 'timbangan'
      },
      {
        netto_1: 9000,
        netto_2: 8500,
        price: 2500,
        dp: 0,
        biaya_bongkar: 12,
        spsi_calculation_mode: 'FIX',
        spsi_rate: 50000,
        spsi_amount: 50000,
        bp_colt: 100000,
        pph: 0,
        uang_minum: 0,
        total: 21100000
      }
    );

    expect(data).toMatchObject({
      relation_agent_id: 'rel-1',
      transport_id: 'transport-1',
      factory_id: 'factory-1',
      factory_spsi_type_id: 'spsi-1',
      spsi_type_name: 'TIMBANGAN',
      spsi_calculation_mode: 'FIX',
      spsi_rate: 50000,
      spsi_amount: 50000
    });
  });

  it('stores Nota recipient from selected Relasi/Agen master', async () => {
    const supabase = new FakeSupabase({
      relation_agents: [{ id: 'rel-1', name: 'AGEN MAJU', address: 'BINJAI' }],
      relation_agent_accounts: [],
      bons: [{ id: 'bon-1', total: 1000, status: 'BELUM_DIBAYAR' }],
      notas: [],
      nota_items: []
    });

    await notaRepository.createNota(supabase, { relation_agent_id: 'rel-1' }, ['bon-1']);

    expect(supabase.tables.notas[0]).toMatchObject({
      relation_agent_id: 'rel-1',
      recipient_name: 'AGEN MAJU',
      recipient_address: 'BINJAI'
    });
  });

  it('stores selected factory on Margin payload', async () => {
    const supabase = new FakeSupabase({
      payments: [{ id: 'pay-1', amount_paid: 1000, margin_id: null }],
      margins: []
    });

    await marginRepository.createMargin(
      supabase,
      { transaction_date: '2026-07-18', factory_id: 'factory-1', offtaker_amount: 2000 },
      ['pay-1']
    );

    expect(supabase.tables.margins[0]).toMatchObject({
      factory_id: 'factory-1',
      real_amount: 1000,
      margin_amount: 1000
    });
  });
});
