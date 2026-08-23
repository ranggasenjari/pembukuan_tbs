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

function getOcrFactories() {
  return window.FACTORIES || [];
}

function getOcrFactoryName(id) {
  return getOcrFactories().find((f) => f.id === id)?.name || '';
}

// Dialog pilih pabrik — self-contained. Kembalikan null bila dibatalkan,
// atau { id, name } (id boleh kosong = default / tanpa pabrik).
function showOcrFactoryDialog() {
  const factories = getOcrFactories();
  const existingId = document.querySelector('[name="factory_id"]')?.value
    || sessionStorage.getItem('ocr_factory_id')
    || '';
  return new Promise((resolve) => {
    const dialog = document.createElement('dialog');
    dialog.id = 'ocr-factory-dialog';
    dialog.className = 'rounded-xl shadow-xl p-6 max-w-md';
    dialog.innerHTML = `
      <h3 class="text-lg font-bold mb-1">Pilih Pabrik</h3>
      <p class="text-sm text-slate-500 mb-4">OCR akan memakai prompt &amp; schema khusus pabrik ini (bila tersedia).</p>
      <select id="ocr-factory-picker" class="form-input mb-4">
        <option value="">(Default / Tanpa Pabrik)</option>
      </select>
      <div class="flex gap-2 justify-end">
        <button type="button" id="ocr-factory-cancel" class="btn-secondary">Batal</button>
        <button type="button" id="ocr-factory-ok" class="btn-primary">Proses OCR</button>
      </div>
    `;
    document.body.appendChild(dialog);
    const picker = dialog.querySelector('#ocr-factory-picker');
    factories.forEach((factory) => {
      const option = document.createElement('option');
      option.value = factory.id;
      option.textContent = factory.name;
      picker.appendChild(option);
    });
    picker.value = existingId && factories.some((f) => f.id === existingId) ? existingId : '';
    dialog.querySelector('#ocr-factory-cancel').addEventListener('click', () => {
      dialog.close();
      resolve(null);
    });
    dialog.querySelector('#ocr-factory-ok').addEventListener('click', () => {
      const id = picker.value;
      dialog.close();
      resolve({ id, name: getOcrFactoryName(id) });
    });
    dialog.showModal();
  });
}

function setOcrFactory(selection) {
  const id = selection?.id || '';
  const name = selection?.name || '';
  sessionStorage.setItem('ocr_factory_id', id);
  const factoryInput = document.querySelector('[name="factory_id"]');
  const factoryNameInput = document.querySelector('[name="factory_name"]');
  if (factoryInput) {
    factoryInput.value = id;
    if (typeof applyFactorySelection === 'function') applyFactorySelection();
    if (factoryNameInput) factoryNameInput.value = name;
  }
}

document.addEventListener('drop', async (e) => {
  if (dropOverlay) dropOverlay.style.display = 'none';

  const files = e.dataTransfer?.files;
  if (!files || files.length === 0) return;
  const file = files[0];
  if (!isImageFile(file)) return;

  // Pilih pabrik dulu (sesuai pengaturan OCR per pabrik)
  let factorySelection = { id: '', name: '' };
  if (getOcrFactories().length) {
    const selection = await showOcrFactoryDialog();
    if (!selection) return; // dibatalkan
    factorySelection = selection;
    setOcrFactory(factorySelection);
  }

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
    if (factorySelection.id) {
      formData.append('factory_id', factorySelection.id);
      formData.append('factory_name', factorySelection.name);
    }

    const baseUrl = window.appUrl ? window.appUrl('') : '';
    const res = await fetch(baseUrl + '/api/ocr/bon', { method: 'POST', body: formData });
    if (!res.ok) throw new Error('OCR gagal dengan status ' + res.status);
    const payload = await res.json();
    const data = extractDropOcrData(payload);
    if (factorySelection.id) {
      data.factory_id = factorySelection.id;
      data.factory_name = factorySelection.name;
    }
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
  if (normalized.factory_id && document.querySelector('[name="factory_id"]')) {
    document.querySelector('[name="factory_id"]').value = normalized.factory_id;
    if (typeof applyFactorySelection === 'function') applyFactorySelection();
  }
  if (normalized.image_url) {
    const input = document.querySelector('[name="ocr_image_url"]');
    if (input) input.value = normalized.image_url;
  }
  if (normalized.image_url && typeof updateBonPhoto === 'function') updateBonPhoto(normalized.image_url);

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