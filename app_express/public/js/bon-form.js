const rupiah = new Intl.NumberFormat('id-ID', { style: 'currency', currency: 'IDR', maximumFractionDigits: 0 });
const ZERO_PPH_UM_FACTORY = 'a536e3c0-7ea0-4003-9df0-c38721a9439b';
const PENGURUS_FACTORY = '376b98eb-0eb4-4a4e-84aa-902429f85669';
function isZeroPphUm() {
  return document.querySelector('[name="factory_id"]')?.value === ZERO_PPH_UM_FACTORY;
}
function isPengurusFactory() {
  return document.querySelector('[name="factory_id"]')?.value === PENGURUS_FACTORY;
}

function num(name) {
  const input = document.querySelector(`[name="${name}"]`);
  return Number(String(input?.value || '0').replace(/[^\d.-]/g, '')) || 0;
}

function setValue(name, value) {
  const input = document.querySelector(`[name="${name}"]`);
  if (input && input.value !== String(value ?? '')) input.value = String(value ?? '');
}

function normalize(value) {
  return String(value || '').replace(/\s+/g, '').trim().toUpperCase();
}

function getSelectedRelation() {
  const relationId = document.querySelector('[name="relation_agent_id"]')?.value || '';
  return (window.RELATION_AGENTS || []).find((relation) => relation.id === relationId) || null;
}

function getSelectedFactory() {
  const factoryId = document.querySelector('[name="factory_id"]')?.value || '';
  return (window.FACTORIES || []).find((factory) => factory.id === factoryId) || null;
}

function findFactoryByName(name) {
  const normalized = normalize(name);
  return (window.FACTORIES || []).find((factory) => normalize(factory.name) === normalized) || null;
}

function setRelationName(clearWhenEmpty = false) {
  const relation = getSelectedRelation();
  if (relation) setValue('relation_name', relation.name);
  else if (clearWhenEmpty) setValue('relation_name', '');
}

function populateSpsiTypes() {
  const select = document.querySelector('[name="factory_spsi_type_id"]');
  if (!select) return;

  const factory = getSelectedFactory();
  const current = select.value || window.CURRENT_BON_SPSI_TYPE_ID;
  select.required = Boolean(factory);
  select.innerHTML = '<option value="">Pilih Jenis SPSI</option>';
  let firstType = null;
  (factory?.factory_spsi_types || []).forEach((type) => {
    const option = document.createElement('option');
    option.value = type.id;
    option.dataset.name = type.name || '';
    option.dataset.mode = type.calculation_mode || 'PER_KG';
    option.dataset.amount = type.amount || 0;
    option.textContent = `${type.name || '-'} (${type.calculation_mode === 'FIX' ? 'Fix' : 'Per/Kg'} - ${rupiah.format(type.amount || 0)})`;
    if (type.id === current) option.selected = true;
    if (!firstType) firstType = option;
    select.appendChild(option);
  });
  // Auto-pilih jenis SPSI default pabrik bila belum ada pilihan.
  if (!current && firstType) firstType.selected = true;
  applySelectedSpsiType();
}

function applySelectedSpsiType() {
  const factoryId = document.querySelector('[name="factory_id"]')?.value || '';
  const bongkarInput = document.querySelector('[name="biaya_bongkar"]');
  const bongkarLabel = document.getElementById('biaya-bongkar-label');
  const option = document.querySelector('[name="factory_spsi_type_id"]')?.selectedOptions?.[0];
  if (factoryId && option?.value) {
    setValue('spsi_type_name', option.dataset.name || '');
    setValue('spsi_calculation_mode', option.dataset.mode || 'PER_KG');
    setValue('spsi_rate', option.dataset.amount || 0);
    setValue('biaya_bongkar', option.dataset.amount || 0);
    if (bongkarInput) bongkarInput.readOnly = true;
    if (bongkarLabel) bongkarLabel.textContent = option.dataset.mode === 'FIX' ? 'Bongkar / SPSI (Fix)' : 'Bongkar (Rp/Kg)';
  } else if (factoryId) {
    setValue('spsi_type_name', '');
    setValue('spsi_calculation_mode', 'PER_KG');
    setValue('spsi_rate', 0);
    setValue('biaya_bongkar', 0);
    if (bongkarInput) bongkarInput.readOnly = true;
    if (bongkarLabel) bongkarLabel.textContent = 'Bongkar (pilih SPSI)';
  } else {
    setValue('spsi_type_name', '');
    setValue('spsi_calculation_mode', 'PER_KG');
    setValue('spsi_rate', num('biaya_bongkar'));
    if (bongkarInput) bongkarInput.readOnly = false;
    if (bongkarLabel) bongkarLabel.textContent = 'Bongkar (Rp/Kg)';
  }
  calculate();
}

function calculateSpsiAmount(netto1) {
  const mode = document.querySelector('[name="spsi_calculation_mode"]')?.value || 'PER_KG';
  const rate = num('biaya_bongkar');
  return mode === 'FIX' ? rate : rate * netto1;
}

function calculate() {
  const netto1 = num('netto_1');
  const netto2 = num('netto_2');
  const price = num('price');
  const subtotal = netto2 * price;
  const zeroRule = isZeroPphUm();
  const pengurusRule = isPengurusFactory();
  const zeroPphUm = zeroRule || pengurusRule;
  const pph = zeroPphUm ? 0 : Math.floor(0.0025 * subtotal);
  const uangMinum = zeroPphUm ? 0 : (netto2 > 7000 ? 20000 : 10000);
  if (pengurusRule) setValue('bp_colt', 0);

  // Hanya auto-hitung jika user belum mengubah manual
  const pphInput = document.querySelector('[name="pph"]');
  const uangMinumInput = document.querySelector('[name="uang_minum"]');
  if (pphInput && !pphInput.dataset.userEdited) setValue('pph', pph);
  if (uangMinumInput && !uangMinumInput.dataset.userEdited) setValue('uang_minum', uangMinum);
  setValue('spsi_rate', num('biaya_bongkar'));

  const spsiAmount = calculateSpsiAmount(netto1);
  const dynamic = [...document.querySelectorAll('.deduction-amount')].reduce((sum, input) => sum + (Number(input.value) || 0), 0);
  const totalDeduction = num('dp') + spsiAmount + num('bp_colt') + num('pph') + num('uang_minum') + dynamic;
  const total = subtotal - totalDeduction;

  document.getElementById('subtotal-display').textContent = rupiah.format(subtotal);
  document.getElementById('deduction-display').textContent = rupiah.format(totalDeduction);
  document.getElementById('total-display').textContent = rupiah.format(total);
  const spsiDisplay = document.getElementById('spsi-display');
  if (spsiDisplay) spsiDisplay.textContent = `SPSI: ${rupiah.format(spsiAmount)}`;
}

document.addEventListener('input', (event) => {
  if (event.target.classList.contains('bon-calc')) calculate();
});

// Tandai jika user mengedit PPh atau Uang Minum secara manual
document.querySelector('[name="pph"]')?.addEventListener('input', function() {
  if (!isZeroPphUm()) this.dataset.userEdited = 'true';
});
document.querySelector('[name="uang_minum"]')?.addEventListener('input', function() {
  if (!isZeroPphUm()) this.dataset.userEdited = 'true';
});

document.querySelector('[name="relation_agent_id"]')?.addEventListener('change', () => {
  setRelationName(true);
});

function applyFactorySelection() {
  const factoryId = document.querySelector('[name="factory_id"]')?.value || '';
  window.CURRENT_BON_SPSI_TYPE_ID = '';
  populateSpsiTypes();
  // Reset userEdited flag untuk PPh dan Uang Minum
  const pphInput = document.querySelector('[name="pph"]');
  const umInput = document.querySelector('[name="uang_minum"]');
  if (pphInput) delete pphInput.dataset.userEdited;
  if (umInput) delete umInput.dataset.userEdited;
  // Isi harga & SPSI sesuai default pabrik
  if (factoryId && window.FACTORY_DEFAULT_PRICES && window.FACTORY_DEFAULT_PRICES[factoryId]) {
    setValue('price', window.FACTORY_DEFAULT_PRICES[factoryId]);
  }
  if (isPengurusFactory()) {
    setValue('bp_colt', 0);
    setValue('pph', 0);
    setValue('uang_minum', 0);
  }
  renderFactoryPricePills();
  calculate();
}

document.querySelector('[name="factory_id"]')?.addEventListener('change', applyFactorySelection);

document.querySelector('[name="factory_spsi_type_id"]')?.addEventListener('change', applySelectedSpsiType);

document.getElementById('add-deduction')?.addEventListener('click', () => {
  const wrapper = document.createElement('div');
  wrapper.className = 'deduction-row grid gap-2 md:grid-cols-[1fr_200px_40px]';
  wrapper.innerHTML = `
    <input name="deduction_label" class="form-input bon-sm" placeholder="Nama potongan">
    <input name="deduction_amount" value="0" type="number" inputmode="numeric" class="form-input bon-sm bon-calc deduction-amount">
    <button type="button" class="remove-deduction rounded-lg bg-rose-50 text-rose-700">x</button>
  `;
  document.getElementById('deductions').appendChild(wrapper);
});

document.addEventListener('click', (event) => {
  if (event.target.classList.contains('remove-deduction')) {
    event.target.closest('.deduction-row')?.remove();
    calculate();
  }
});

function matchOcrToMasters() {
  const relationName = normalize(document.querySelector('[name="relation_name"]')?.value);
  const relation = (window.RELATION_AGENTS || []).find((item) => normalize(item.name) === relationName);

  if (relation) setValue('relation_agent_id', relation.id);
  setRelationName(false);

  const factoryName = normalize(document.querySelector('[name="factory_name"]')?.value || document.querySelector('[name="fruit_origin"]')?.value);
  const factory = findFactoryByName(factoryName);
  if (factory) {
    setValue('factory_id', factory.id);
    applyFactorySelection();
  }
  syncRelationCombobox();
}

function extractOcrData(payload) {
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

function applyOcrFields(data) {
  ['ticket_number', 'bon_date', 'plate_number', 'driver_name', 'relation_name', 'factory_name', 'fruit_origin', 'notes', 'netto_1', 'netto_2'].forEach((key) => {
    const input = document.querySelector(`[name="${key}"]`);
    if (input && data[key] !== undefined && data[key] !== null) input.value = data[key];
  });
  if (data.image_url) {
    const input = document.querySelector('[name="ocr_image_url"]');
    if (input) input.value = data.image_url;
  }
  if (data.image_url && typeof updateBonPhoto === 'function') updateBonPhoto(data.image_url);
}

document.getElementById('ocr-button')?.addEventListener('click', async () => {
  const fileInput = document.getElementById('bon-image');
  const status = document.getElementById('ocr-status');
  if (!fileInput.files.length) {
    status.textContent = 'Pilih gambar terlebih dahulu.';
    return;
  }
  if (window.FACTORIES && window.FACTORIES.length) {
    const selection = await showOcrFactoryDialog();
    if (!selection) return;
    if (selection.id) setOcrFactory(selection);
  }

  const formData = new FormData();
  formData.append('file', fileInput.files[0]);
  const factoryId = document.querySelector('[name="factory_id"]')?.value || sessionStorage.getItem('ocr_factory_id') || '';
  if (factoryId) {
    formData.append('factory_id', factoryId);
    formData.append('factory_name', document.querySelector('[name="factory_name"]')?.value || '');
  }
  status.textContent = 'Membaca OCR...';
  try {
    const response = await fetch(window.appUrl ? window.appUrl('/api/ocr/bon') : '/api/ocr/bon', { method: 'POST', body: formData });
    const payload = await response.json();
    if (!response.ok) throw new Error(payload.error || 'OCR gagal');
    const data = extractOcrData(payload);
    applyOcrFields(data);
    matchOcrToMasters();
    calculate();
    status.textContent = 'Data bon berhasil terbaca.';
  } catch (error) {
    status.textContent = error.message;
  }
});

function renderFactoryPricePills() {
  const container = document.getElementById('factory-price-pills');
  if (!container) return;
  const factory = getSelectedFactory();
  container.innerHTML = '';
  if (!factory) return;
  const prices = Array.isArray(factory.factory_prices) ? factory.factory_prices : [];
  if (!prices.length) return;
  const priceInput = document.querySelector('[name="price"]');
  prices.forEach((p) => {
    const pill = document.createElement('button');
    pill.type = 'button';
    pill.className = 'price-pill' + (priceInput && Number(priceInput.value) === Number(p.price) ? ' active' : '');
    pill.textContent = `${p.name || 'Harga'}: ${rupiah.format(Number(p.price) || 0)}`;
    pill.title = p.name || '';
    pill.addEventListener('click', () => {
      if (!priceInput || priceInput.readOnly) return;
      priceInput.value = p.price;
      priceInput.dispatchEvent(new Event('input'));
      renderFactoryPricePills();
    });
    container.appendChild(pill);
  });
}

document.querySelector('[name="price"]')?.addEventListener('input', renderFactoryPricePills);

function syncRelationCombobox() {
  const select = document.getElementById('relation-select');
  const search = document.getElementById('relation-search');
  if (!select || !search) return;
  const rel = (window.RELATION_AGENTS || []).find((r) => r.id === select.value);
  search.value = rel ? rel.name : '';
  renderRelationList(search.value);
}

function renderRelationList(filter) {
  const list = document.getElementById('relation-list');
  const select = document.getElementById('relation-select');
  if (!list || !select) return;
  const term = String(filter || '').trim().toLowerCase();
  const rels = (window.RELATION_AGENTS || []).filter((r) => !term || String(r.name || '').toLowerCase().includes(term));
  const selectedId = select.value;
  list.innerHTML = '';
  const label = document.createElement('div');
  label.className = 'relation-list-label';
  label.textContent = rels.length ? 'Pilih relasi:' : 'Relasi tidak ditemukan';
  list.appendChild(label);
  rels.forEach((r) => {
    const item = document.createElement('button');
    item.type = 'button';
    item.className = 'relation-list-item' + (r.id === selectedId ? ' active' : '');
    item.textContent = r.name;
    item.addEventListener('click', () => {
      select.value = r.id;
      syncRelationCombobox();
      setRelationName(true);
      closeRelationList();
    });
    list.appendChild(item);
  });
}

function openRelationList() {
  const list = document.getElementById('relation-list');
  if (!list) return;
  renderRelationList(document.getElementById('relation-search')?.value || '');
  list.classList.remove('hidden');
}

function closeRelationList() {
  document.getElementById('relation-list')?.classList.add('hidden');
}

function initRelationCombobox() {
  const search = document.getElementById('relation-search');
  const select = document.getElementById('relation-select');
  if (!search || !select) return;
  search.addEventListener('focus', openRelationList);
  search.addEventListener('input', () => openRelationList());
  document.getElementById('relation-clear')?.addEventListener('click', () => {
    select.value = '';
    syncRelationCombobox();
    setRelationName(true);
    search.focus();
  });
  document.addEventListener('click', (e) => {
    if (!e.target.closest('.relation-combobox')) closeRelationList();
  });
  select.addEventListener('change', syncRelationCombobox);
  syncRelationCombobox();
}

const relationForm = document.getElementById('bon-form');
if (relationForm) {
  relationForm.addEventListener('submit', (e) => {
    const select = document.getElementById('relation-select');
    if (select && !select.value) {
      e.preventDefault();
      alert('Pilih relasi / agen terlebih dahulu.');
      const search = document.getElementById('relation-search');
      if (search) { search.focus(); openRelationList(); }
    }
  });
}

initRelationCombobox();
renderFactoryPricePills();
calculate();
setRelationName();
populateSpsiTypes();
