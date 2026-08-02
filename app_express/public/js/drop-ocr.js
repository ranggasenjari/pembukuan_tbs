let dropOverlay = null;

function ensureDropOverlay() {
  if (dropOverlay) return;
  dropOverlay = document.createElement('div');
  dropOverlay.id = 'drop-overlay';
  dropOverlay.innerHTML = '<div class="drop-content"><svg width="48" height="48" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" style="display:block;margin:0 auto"><path d="M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4"/><polyline points="17 8 12 3 7 8"/><line x1="12" y1="3" x2="12" y2="15"/></svg><p>Lepaskan gambar untuk OCR</p></div>';
  Object.assign(dropOverlay.style, {
    position: 'fixed', inset: '0', zIndex: '9999',
    display: 'none', alignItems: 'center', justifyContent: 'center',
    background: 'rgba(67, 24, 255, 0.85)', backdropFilter: 'blur(4px)',
    color: '#fff', fontSize: '1.5rem', fontWeight: 'bold',
    fontFamily: 'system-ui, sans-serif'
  });
  const style = document.createElement('style');
  style.textContent = `
    #drop-overlay .drop-content { text-align: center; }
    #drop-overlay .drop-content p { margin-top: 16px; }
  `;
  document.head.appendChild(style);
  document.body.appendChild(dropOverlay);

  ['dragenter', 'dragover', 'dragleave', 'drop'].forEach((evt) => {
    document.addEventListener(evt, (e) => { e.preventDefault(); e.stopPropagation(); }, false);
  });

  document.addEventListener('dragenter', () => { dropOverlay.style.display = 'flex'; }, false);
  document.addEventListener('dragleave', (e) => {
    if (e.relatedTarget === null || e.relatedTarget === document.body) {
      dropOverlay.style.display = 'none';
    }
  }, false);
}

function isImageFile(file) {
  return file && file.type && file.type.startsWith('image/');
}

function extractDropOcrData(payload) {
  const container = payload?.data || payload || {};
  let annotation = container.document_annotation || container;
  if (typeof annotation === 'string') {
    try { annotation = JSON.parse(annotation); } catch { annotation = {}; }
  }
  const data = { ...annotation };
  if (payload?.image_url) data.image_url = payload.image_url;
  if (container.image_url) data.image_url = container.image_url;
  return data;
}

document.addEventListener('drop', async (e) => {
  if (dropOverlay) dropOverlay.style.display = 'none';

  const files = e.dataTransfer?.files;
  if (!files || files.length === 0) return;
  const file = files[0];
  if (!isImageFile(file)) return;

  const status = document.getElementById('drop-status') || (() => {
    const el = document.createElement('div');
    el.id = 'drop-status';
    el.innerHTML = '<div style="text-align:center"><svg width="48" height="48" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" style="display:block;margin:0 auto 16px;animation:spin 1s linear infinite"><path d="M21 12a9 9 0 1 1-6.219-8.56"/></svg><p style="font-size:1.25rem;font-weight:bold">Memproses OCR...</p><p style="font-size:0.875rem;margin-top:8px;opacity:0.8">Silakan tunggu sebentar</p></div>';
    Object.assign(el.style, {
      position: 'fixed', inset: '0', zIndex: '10000',
      display: 'none', alignItems: 'center', justifyContent: 'center',
      background: 'rgba(15, 23, 42, 0.85)', backdropFilter: 'blur(4px)',
      color: '#fff', fontFamily: 'system-ui, sans-serif'
    });
    const spinStyle = document.createElement('style');
    spinStyle.textContent = '@keyframes spin { to { transform: rotate(360deg); } }';
    document.head.appendChild(spinStyle);
    document.body.appendChild(el);
    return el;
  })();
  status.style.display = 'flex';

  try {
    const formData = new FormData();
    formData.append('file', file, file.name || 'bon.jpg');

    const baseUrl = window.appUrl ? window.appUrl('') : '';
    const res = await fetch(baseUrl + '/api/ocr/bon', { method: 'POST', body: formData });
    if (!res.ok) throw new Error('OCR gagal dengan status ' + res.status);
    const payload = await res.json();
    const data = extractDropOcrData(payload);
    sessionStorage.setItem('ocr_data', JSON.stringify(data));
    status.innerHTML = '<div style="text-align:center"><svg width="48" height="48" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" style="display:block;margin:0 auto 16px;color:#86efac"><polyline points="20 6 9 17 4 12"/></svg><p style="font-size:1.25rem;font-weight:bold">OK, mengarahkan...</p></div>';

    const currentPath = window.location.pathname.replace(window.APP_BASE_PATH || '', '') || '';
    if (currentPath.includes('/bons/new')) {
      applyOcrData();
      status.style.display = 'none';
    } else {
      const target = (window.appUrl ? window.appUrl('/bons/new') : '/bons/new');
      window.location.href = target;
    }
  } catch (err) {
    status.innerHTML = '<div style="text-align:center"><svg width="48" height="48" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" style="display:block;margin:0 auto 16px;color:#fca5a5"><circle cx="12" cy="12" r="10"/><line x1="15" y1="9" x2="9" y2="15"/><line x1="9" y1="9" x2="15" y2="15"/></svg><p style="font-size:1.25rem;font-weight:bold">OCR Gagal</p><p style="font-size:0.875rem;margin-top:8px;opacity:0.8">' + err.message + '</p></div>';
    setTimeout(() => { status.style.display = 'none'; }, 3000);
  }
}, false);

function applyOcrData() {
  const raw = sessionStorage.getItem('ocr_data');
  if (!raw) return;
  sessionStorage.removeItem('ocr_data');
  let data;
  try { data = JSON.parse(raw); } catch { return; }

  const normalized = extractDropOcrData({ data });
  ['ticket_number', 'bon_date', 'plate_number', 'driver_name', 'relation_name', 'factory_name', 'fruit_origin', 'notes', 'netto_1', 'netto_2'].forEach((key) => {
    if (normalized[key] !== undefined && normalized[key] !== null) {
      const input = document.querySelector(`[name="${key}"]`);
      if (input) input.value = normalized[key];
    }
  });
  if (normalized.image_url) {
    const input = document.querySelector('[name="ocr_image_url"]');
    if (input) input.value = normalized.image_url;
  }

  if (typeof matchOcrToMasters === 'function') matchOcrToMasters();
  if (typeof calculate === 'function') calculate();

  const btn = document.getElementById('ocr-button');
  if (btn) {
    const status = document.getElementById('ocr-status');
    if (status) status.textContent = 'Data bon berhasil terbaca dari drag & drop.';
  }
}

document.addEventListener('DOMContentLoaded', () => {
  ensureDropOverlay();
  applyOcrData();
});
