const { createAnonClient } = require('../config/supabase');
const { env } = require('../config/env');

const clients = new Map();
let channel;
let pollTimer;

const TABLE_LABELS = {
  bons: 'Bon',
  bon_deductions: 'Potongan Bon',
  notas: 'Nota',
  nota_items: 'Item Nota',
  payments: 'Pembayaran',
  payment_relations: 'Relasi Bayar',
  payment_relation_accounts: 'Rekening Relasi Bayar',
  payment_relation_vehicles: 'Kendaraan Relasi Bayar',
  relation_agents: 'Relasi/Agen',
  relation_agent_accounts: 'Rekening Relasi/Agen',
  vehicles: 'Kendaraan',
  factories: 'Pabrik',
  factory_spsi_types: 'Jenis SPSI',
  factory_prices: 'Harga Pabrik',
  margins: 'Margin',
  expenses: 'Pengeluaran',
  expense_margins: 'Margin Pengeluaran',
  deposits: 'Deposit'
};

const ACTION_LABELS = {
  INSERT: 'ditambahkan',
  UPDATE: 'diubah',
  DELETE: 'dihapus'
};

const moneyFormatter = new Intl.NumberFormat('id-ID', {
  style: 'currency',
  currency: 'IDR',
  maximumFractionDigits: 0
});

function keyFieldFor(table, row) {
  if (!row) return '';
  switch (table) {
    case 'bons':
    case 'vehicles':
      return row.plate_number ? ` ${row.plate_number}` : (row.ticket_number ? ` ${row.ticket_number}` : '');
    case 'notas':
      return row.invoice_number ? ` ${row.invoice_number}` : '';
    case 'payments':
      return row.amount_paid ? ` ${moneyFormatter.format(row.amount_paid)}` : '';
    case 'payment_relations':
    case 'relation_agents':
    case 'factories':
      return row.name ? ` ${row.name}` : '';
    case 'bon_deductions':
    case 'expenses':
      return row.label ? ` ${row.label}` : '';
    default:
      return '';
  }
}

function buildDescription(table, type, newRow, oldRow) {
  const label = TABLE_LABELS[table] || table;
  const action = ACTION_LABELS[type] || (type ? ` di${String(type).toLowerCase()}` : 'berubah');
  const row = type === 'DELETE' ? oldRow : newRow;
  const key = keyFieldFor(table, row);
  return `${label}${key} ${action}`;
}

function broadcast(event, payload = {}) {
  const message = `data: ${JSON.stringify({ event, payload })}\n\n`;
  clients.forEach((client) => client.res.write(message));
}

function attachClient(req, res) {
  const id = `${Date.now()}-${Math.random().toString(16).slice(2)}`;
  res.setHeader('Content-Type', 'text/event-stream');
  res.setHeader('Cache-Control', 'no-cache');
  res.setHeader('Connection', 'keep-alive');
  res.flushHeaders?.();
  res.write(`data: ${JSON.stringify({ event: 'connected', payload: { id } })}\n\n`);

  const heartbeat = setInterval(() => res.write(': heartbeat\n\n'), 30_000);
  clients.set(id, { res, heartbeat });

  req.on('close', () => {
    clearInterval(heartbeat);
    clients.delete(id);
  });
}

function startPollingFallback() {
  if (pollTimer) return;
  pollTimer = setInterval(() => broadcast('refresh', { source: 'poll' }), 30_000);
}

function setupRealtime() {
  if (channel || !env.supabaseUrl || !env.supabaseAnonKey) return;
  const supabase = createAnonClient();
  channel = supabase.channel('express_realtime_db_changes');
  const tables = [
    'bons', 'bon_deductions', 'notas', 'nota_items', 'payments',
    'payment_relations', 'payment_relation_accounts', 'payment_relation_vehicles',
    'relation_agents', 'relation_agent_accounts', 'vehicles', 'factories', 'factory_spsi_types', 'factory_prices',
    'margins', 'expenses', 'expense_margins', 'deposits'
  ];

  tables.forEach((table) => {
    channel.on(
      'postgres_changes',
      { event: '*', schema: env.supabaseSchema, table },
      (payload) => {
        console.log(`[realtime] change on ${table}: ${payload.eventType}`);
        const description = buildDescription(table, payload.eventType, payload.new, payload.old);
        broadcast('refresh', { table, type: payload.eventType, description });
      }
    );
  });

  channel.subscribe((status, err) => {
    console.log(`[realtime] channel status: ${status}`, err ? err.message : '');
    if (status === 'SUBSCRIBED') {
      console.log('[realtime] subscribed to postgres_changes');
      if (pollTimer) { clearInterval(pollTimer); pollTimer = null; }
    }
    if (status === 'TIMED_OUT' || status === 'CHANNEL_ERROR') startPollingFallback();
  });
  channel.on('error', (e) => console.error('[realtime] channel error:', e.message));

}

module.exports = { attachClient, broadcast, buildDescription, setupRealtime };
