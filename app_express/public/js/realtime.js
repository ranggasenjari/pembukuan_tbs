(function() {
  if (window._realtimeInitialized) return;
  window._realtimeInitialized = true;

  const basePath = window.appBasePath || window.location.pathname.match(/^\/[^/]+/)?.[0] || '';
  const eventUrl = basePath + '/api/events';
  const STORAGE_KEY = 'realtime.lastChanges';
  const MAX_PENDING = 5;

  let es;
  let lastRefresh = 0;
  const THROTTLE_MS = 2000;
  const tables = [
    'bons', 'bon_deductions', 'notas', 'nota_items', 'payments',
    'payment_relations', 'payment_relation_accounts', 'payment_relation_vehicles',
    'relation_agents', 'relation_agent_accounts', 'vehicles', 'factories',
    'factory_spsi_types', 'factory_prices'
  ];

  function injectStyles() {
    if (document.getElementById('realtime-toast-style')) return;
    const style = document.createElement('style');
    style.id = 'realtime-toast-style';
    style.textContent = `
      #realtime-toast {
        align-items: flex-start;
        background: #1e293b;
        border-radius: 10px;
        box-shadow: 0 12px 32px rgb(15 23 42 / .28);
        color: #f8fafc;
        display: flex;
        font-size: .78rem;
        gap: 8px;
        left: 16px;
        line-height: 1.4;
        max-width: min(360px, calc(100vw - 32px));
        opacity: 0;
        padding: 10px 12px;
        pointer-events: none;
        position: fixed;
        top: 16px;
        transform: translateY(-8px);
        transition: opacity .25s ease, transform .25s ease;
        z-index: 9999;
      }
      #realtime-toast.show {
        opacity: 1;
        pointer-events: auto;
        transform: translateY(0);
      }
      #realtime-toast-icon {
        align-items: center;
        background: #10b981;
        border-radius: 50%;
        display: flex;
        flex-shrink: 0;
        height: 20px;
        justify-content: center;
        margin-top: 1px;
        width: 20px;
      }
      #realtime-toast-icon::before {
        border: solid #fff;
        border-width: 0 2px 2px 0;
        content: '';
        height: 8px;
        margin-top: -2px;
        transform: rotate(45deg);
        width: 4px;
      }
      #realtime-toast-title {
        font-weight: 800;
        font-size: .68rem;
        letter-spacing: .04em;
        margin-bottom: 2px;
        text-transform: uppercase;
      }
      #realtime-toast-close {
        background: transparent;
        border: 0;
        color: #94a3b8;
        cursor: pointer;
        flex-shrink: 0;
        font-size: 1rem;
        line-height: 1;
        margin: -2px -4px 0 0;
        padding: 0 4px;
      }
      #realtime-toast-close:hover { color: #e2e8f0; }
    `;
    document.head.appendChild(style);
  }

  function showToast(items) {
    injectStyles();
    const existing = document.getElementById('realtime-toast');
    if (existing) existing.remove();

    const toast = document.createElement('div');
    toast.id = 'realtime-toast';
    toast.innerHTML =
      '<span id="realtime-toast-icon"></span>' +
      '<span id="realtime-toast-body">' +
        '<div id="realtime-toast-title">Perubahan Data</div>' +
        '<div id="realtime-toast-list"></div>' +
      '</span>' +
      '<button id="realtime-toast-close" type="button" title="Tutup">&times;</button>';
    const list = toast.querySelector('#realtime-toast-list');
    list.innerHTML = items.map((item) => `<div>${item}</div>`).join('');
    toast.querySelector('#realtime-toast-close').addEventListener('click', () => {
      toast.classList.remove('show');
      setTimeout(() => toast.remove(), 250);
    });
    document.body.appendChild(toast);
    requestAnimationFrame(() => toast.classList.add('show'));
    setTimeout(() => {
      toast.classList.remove('show');
      setTimeout(() => toast.remove(), 250);
    }, 30000);
  }

  function savePending(description) {
    try {
      let items = [];
      try { items = JSON.parse(sessionStorage.getItem(STORAGE_KEY) || '[]'); } catch (e) { items = []; }
      if (!Array.isArray(items)) items = [];
      if (description) {
        // Hindari duplikat berurutan (broadcast app + channel DB untuk perubahan yang sama)
        if (items[items.length - 1] !== description) {
          items.push(description);
          if (items.length > MAX_PENDING) items = items.slice(items.length - MAX_PENDING);
        }
      }
      sessionStorage.setItem(STORAGE_KEY, JSON.stringify(items));
    } catch (e) {}
  }

  function showPendingToast() {
    try {
      const items = JSON.parse(sessionStorage.getItem(STORAGE_KEY) || '[]');
      sessionStorage.removeItem(STORAGE_KEY);
      if (Array.isArray(items) && items.length) showToast(items);
    } catch (e) {}
  }

  function playDing() {
    try {
      const ctx = new (window.AudioContext || window.webkitAudioContext)();
      const osc = ctx.createOscillator();
      const gain = ctx.createGain();
      osc.connect(gain);
      gain.connect(ctx.destination);
      osc.type = 'sine';
      osc.frequency.setValueAtTime(880, ctx.currentTime);
      osc.frequency.setValueAtTime(1100, ctx.currentTime + 0.08);
      gain.gain.setValueAtTime(0.3, ctx.currentTime);
      gain.gain.exponentialRampToValueAtTime(0.01, ctx.currentTime + 0.3);
      osc.start(ctx.currentTime);
      osc.stop(ctx.currentTime + 0.3);
    } catch (e) {
      // Audio not supported
    }
  }

  function refreshPage(notify = true) {
    const now = Date.now();
    if (now - lastRefresh < THROTTLE_MS) return;
    lastRefresh = now;
    if (notify) playDing();
    // Reload the current view data without full page refresh
    const table = document.querySelector('table');
    if (table) {
      const filterForm = document.querySelector('.filter-bar') || document.querySelector('form');
      if (filterForm && typeof filterForm.requestSubmit === 'function') {
        filterForm.requestSubmit();
      } else {
        window.location.reload();
      }
    } else {
      window.location.reload();
    }
  }

  function connect() {
    if (es) es.close();
    es = new EventSource(eventUrl);

    es.onopen = function() {
      const statusEl = document.getElementById('realtime-status');
      if (statusEl) { statusEl.textContent = '●'; statusEl.style.color = '#22c55e'; statusEl.title = 'Realtime terhubung'; }
    };

    es.onmessage = function(e) {
      try {
        const data = JSON.parse(e.data);
        if (data.event !== 'refresh') return;
        if (data.payload && tables.includes(data.payload.table)) {
          // Perubahan data nyata: suara + toast + reload
          savePending(data.payload.description || null);
          refreshPage(true);
        } else {
          // Poll fallback / resync (tanpa tabel, saat channel DB down atau baru pulih):
          // reload diam agar data tetap segar tanpa suara & toast
          refreshPage(false);
        }
      } catch (err) {
        // Pesan tidak valid bukan perubahan data: abaikan
      }
    };

    es.onerror = function() {
      const statusEl = document.getElementById('realtime-status');
      if (statusEl) { statusEl.textContent = '●'; statusEl.style.color = '#ef4444'; statusEl.title = 'Realtime terputus'; }
      es.close();
      setTimeout(connect, 5000);
    };
  }

  function init() {
    showPendingToast();
    if (document.readyState === 'loading') {
      document.addEventListener('DOMContentLoaded', connect);
    } else {
      connect();
    }
  }

  init();
})();
