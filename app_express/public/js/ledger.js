const statusEl = document.getElementById('conn-status');

if (window.EventSource && statusEl) {
  const source = new EventSource(window.appUrl ? window.appUrl('/api/events') : '/api/events');
  source.onmessage = (event) => {
    try {
      const message = JSON.parse(event.data);
      statusEl.textContent = `Realtime: ${message.event}`;
      if (message.event === 'refresh') {
        statusEl.textContent = 'Realtime update diterima. Refresh halaman untuk melihat data terbaru.';
      }
    } catch {
      statusEl.textContent = 'Realtime aktif';
    }
  };
  source.onerror = () => {
    statusEl.textContent = 'Realtime terputus, mencoba ulang...';
  };
}
