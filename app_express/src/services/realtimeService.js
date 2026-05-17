const { createAnonClient } = require('../config/supabase');
const { env } = require('../config/env');

const clients = new Map();
let channel;
let pollTimer;

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
  const tables = ['bons', 'bon_deductions', 'notas', 'nota_items', 'payments', 'margins', 'expenses', 'expense_margins', 'deposits'];

  tables.forEach((table) => {
    channel.on(
      'postgres_changes',
      { event: '*', schema: env.supabaseSchema, table },
      (payload) => broadcast('refresh', { table, type: payload.eventType })
    );
  });

  channel.subscribe((status) => {
    if (status === 'TIMED_OUT' || status === 'CHANNEL_ERROR') startPollingFallback();
  });
}

module.exports = { attachClient, broadcast, setupRealtime };
