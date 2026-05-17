require('dotenv').config();
const express = require('express');
const path = require('path');
const { createClient } = require('@supabase/supabase-js');

const app = express();
const port = process.env.PORT || 3000;

// Supabase Initialization
const supabase = createClient(process.env.SUPABASE_URL, process.env.SUPABASE_KEY, {
    db: { schema: process.env.SUPABASE_SCHEMA || 'inv' },
    auth: { persistSession: false },
    global: {
        // Handle potential SSL issues for self-hosted
        fetch: (...args) => {
            const [url, config] = args;
            return fetch(url, {
                ...config,
                // You might need to add specific headers or agent settings here if required
            });
        }
    }
});

// For absolute debug: if you suspect SSL issues on self-hosted
process.env.NODE_TLS_REJECT_UNAUTHORIZED = '0';

// Test Connection
(async () => {
    console.log(`[Database] Testing connection to URL: ${process.env.SUPABASE_URL}`);
    console.log(`[Database] Schema: ${process.env.SUPABASE_SCHEMA || 'inv'}`);
    try {
        const { data, error } = await supabase.from('bons').select('count', { count: 'exact', head: true });
        if (error) {
            console.error('[Database] Connection test FAILED:', error);
        } else {
            console.log(`[Database] Connection test SUCCESS. Found data in 'bons' table.`);
        }
    } catch (e) {
        console.error('[Database] CRITICAL fetch error:', e.message);
    }
})();

// SSE Clients state
let clients = [];

// Middleware
app.use(express.static(__dirname));

// SSE Endpoint
app.get('/api/events', (req, res) => {
    res.setHeader('Content-Type', 'text/event-stream');
    res.setHeader('Cache-Control', 'no-cache');
    res.setHeader('Connection', 'keep-alive');
    res.flushHeaders();

    const clientId = Date.now();
    console.log(`[SSE] Client ${clientId} connected. Total clients: ${clients.length + 1}`);

    const newClient = { id: clientId, res };
    clients.push(newClient);

    // Heartbeat every 30s to keep connection alive
    const heartbeat = setInterval(() => {
        res.write(': heartbeat\n\n');
    }, 30000);

    req.on('close', () => {
        console.log(`[SSE] Client ${clientId} disconnected.`);
        clearInterval(heartbeat);
        clients = clients.filter(c => c.id !== clientId);
    });
});

function broadcast(event, payload = {}) {
    console.log(`[SSE] Broadcasting event: ${event} to ${clients.length} clients`);
    clients.forEach(c => c.res.write(`data: ${JSON.stringify({ event, payload })}\n\n`));
}

// Supabase Realtime Subscriptions (on Server)
const setupRealtime = () => {
    const schema = process.env.SUPABASE_SCHEMA || 'inv';
    console.log(`[Realtime] Initializing subscription for schema: ${schema}`);

    // Create a new channel for database changes
    const channel = supabase.channel('realtime_db_changes');

    const tables = ['bons', 'notas', 'payments', 'margins', 'expenses', 'expense_margins', 'nota_items'];

    tables.forEach(table => {
        console.log(`[Realtime] Subscribing to table: ${schema}.${table}`);
        channel.on('postgres_changes',
            {
                event: '*',
                schema: schema,
                table: table
            },
            (payload) => {
                console.log(`[Realtime] Change in ${table}:`, payload.eventType, payload.new?.id || '');
                broadcast('refresh', { table, type: payload.eventType });
            }
        );
    });

    channel.subscribe((status, err) => {
        if (status === 'SUBSCRIBED') {
            console.log(`[Realtime] SUCCESS: Subscribed to schema "${schema}"`);
        } else {
            console.log(`[Realtime] Status: ${status}`);
            if (err) console.error('[Realtime] Detail:', err);

            // Fallback: If Realtime is not working, start backend polling
            if (status === 'TIMED_OUT' || status === 'CHANNEL_ERROR') {
                console.log('[Realtime] Starting backend polling fallback...');
                startPolling();
            }
        }
    });
};

let pollTimer;
const startPolling = () => {
    if (pollTimer) return;
    pollTimer = setInterval(() => {
        console.log('[Poll] Checking for updates via backend poll...');
        broadcast('refresh', { source: 'poll' });
    }, 30000); // Poll every 30 seconds
};

// Periodic Backend Heartbeat for Logs
setInterval(() => {
    console.log(`[Heartbeat] Clients connected: ${clients.length} | Time: ${new Date().toLocaleTimeString()}`);
}, 10000);

setupRealtime();

// API Endpoints
app.get('/api/summary', async (req, res) => {
    try {
        const sinceDate = req.query.since || new Date(new Date().getFullYear(), new Date().getMonth(), 1).toISOString().split('T')[0];

        const [expenses, bons, payments, margins] = await Promise.all([
            supabase.from('expenses').select('amount').gte('expense_date', sinceDate),
            supabase.from('bons').select('netto_1, netto_2').gte('bon_date', sinceDate),
            supabase.from('payments').select('amount_paid').gte('payment_date', sinceDate),
            supabase.from('margins').select('margin_amount').gte('transaction_date', sinceDate)
        ]);

        const totalWeight = (bons.data || []).reduce((sum, b) => sum + (Number(b.netto_2) || Number(b.netto_1)), 0) / 1000;
        const totalPayment = (payments.data || []).reduce((sum, p) => sum + Number(p.amount_paid), 0);
        const totalExp = (expenses.data || []).reduce((sum, e) => sum + Number(e.amount), 0);
        const totalMargin = (margins.data || []).reduce((sum, m) => sum + Number(m.margin_amount), 0);

        res.json({
            totalWeight,
            totalPayment,
            totalExp,
            totalNetProfit: totalMargin - totalExp
        });
    } catch (error) {
        res.status(500).json({ error: error.message });
    }
});

app.get('/api/ledger', async (req, res) => {
    try {
        const { start, end } = req.query;

        // 1. Fetch Margins (Settled)
        let marginQuery = supabase.from('margins').select(`
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
        `).order('transaction_date', { ascending: false });

        if (start) marginQuery = marginQuery.gte('transaction_date', start);
        if (end) marginQuery = marginQuery.lte('transaction_date', end + 'T23:59:59');

        const { data: margins, error: mError } = await marginQuery;
        if (mError) throw mError;

        // 2. Fetch In-Progress Bons
        const { data: inProgressBons, error: ipError } = await supabase.from('bons').select(`
            *,
            bon_deductions(*),
            nota_items (
                notas (
                    *,
                    payments (*)
                )
            )
        `).order('bon_date', { ascending: false });

        if (ipError) throw ipError;

        const filteredIP = (inProgressBons || []).filter(bon => {
            const notaItem = bon.nota_items && bon.nota_items[0];
            if (!notaItem) return true;
            const nota = notaItem.notas;
            if (!nota) return true;
            const payments = nota.payments || [];
            if (payments.length === 0) return true;
            return payments.every(p => !p.margin_id);
        });

        res.json({ margins, inProgress: filteredIP });
    } catch (error) {
        res.status(500).json({ error: error.message });
    }
});

app.listen(port, () => {
    console.log(`Secure Live Ledger Dashboard running at http://localhost:${port}`);
});
