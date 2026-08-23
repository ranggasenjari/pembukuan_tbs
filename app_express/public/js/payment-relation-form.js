document.getElementById('add-payment-relation-account')?.addEventListener('click', () => {
  const wrapper = document.createElement('div');
  wrapper.className = 'payment-relation-account-row grid gap-3 md:grid-cols-[1fr_1fr_1fr_48px]';
  wrapper.innerHTML = `
    <input name="bank_name" class="form-input uppercase" placeholder="Nama Bank">
    <input name="account_number" class="form-input" placeholder="No Rekening">
    <input name="account_name" class="form-input uppercase" placeholder="Nama Rekening">
    <button type="button" class="remove-row rounded-lg bg-rose-50 text-rose-700">x</button>
  `;
  document.getElementById('payment-relation-accounts').appendChild(wrapper);
});

function addDatedRow(prefix, containerId) {
  const wrapper = document.createElement('div');
  wrapper.className = 'dated-row grid gap-3 md:grid-cols-[170px_180px_1fr_48px]';
  wrapper.innerHTML = `
    <input name="${prefix}_tanggal" type="date" class="form-input compact">
    <input name="${prefix}_amount" type="number" inputmode="numeric" value="0" class="form-input compact" placeholder="Rp">
    <input name="${prefix}_notes" class="form-input compact" placeholder="Catatan">
    <button type="button" class="remove-row rounded-lg bg-rose-50 text-rose-700">x</button>
  `;
  document.getElementById(containerId).appendChild(wrapper);
}

document.getElementById('add-hutang')?.addEventListener('click', () => addDatedRow('hutang', 'hutang-rows'));
document.getElementById('add-rolling')?.addEventListener('click', () => addDatedRow('rolling', 'rolling-rows'));
document.getElementById('add-giringan')?.addEventListener('click', () => {
  const wrapper = document.createElement('div');
  wrapper.className = 'giringan-row flex gap-3';
  wrapper.innerHTML = `
    <input name="giringan_name" class="form-input uppercase" placeholder="Nama giringan">
    <button type="button" class="remove-row rounded-lg bg-rose-50 text-rose-700">x</button>
  `;
  document.getElementById('giringan-rows').appendChild(wrapper);
});

document.addEventListener('click', (event) => {
  if (event.target.classList.contains('remove-row') || event.target.classList.contains('remove-payment-relation-account')) {
    event.target.closest('.payment-relation-account-row, .dated-row, .giringan-row')?.remove();
  }
});

// Vehicle picker - Flutter style: searchable bottom sheet + chips (multiple text field style)
(function() {
  const field = document.getElementById('vehicle-field');
  const modal = document.getElementById('vehicle-modal');
  const backdrop = document.getElementById('vehicle-modal-backdrop');
  const okBtn = document.getElementById('vehicle-modal-ok');
  const searchInput = document.getElementById('vehicle-search');
  const list = document.getElementById('vehicle-list');
  const hiddenContainer = document.getElementById('vehicle-checkboxes');
  const chipsContainer = document.getElementById('vehicle-chips');
  const placeholder = document.getElementById('vehicle-placeholder');
  const countEl = document.getElementById('vehicle-count');
  const emptyEl = document.getElementById('vehicle-empty');
  if (!field || !modal || !hiddenContainer) return;

  const hiddenChecks = Array.from(hiddenContainer.querySelectorAll('input[type="checkbox"][name="vehicle_ids"]'));
  const optionChecks = Array.from(list ? list.querySelectorAll('.vehicle-check') : []);
  const optionLabels = Array.from(list ? list.querySelectorAll('.vehicle-option') : []);

  // Build lookup: id -> {plate, driver}
  const metaById = {};
  hiddenChecks.forEach((el) => {
    metaById[el.value] = { plate: el.dataset.plate || el.value, driver: el.dataset.driver || '' };
  });
  optionChecks.forEach((el) => {
    const label = el.closest('.vehicle-option');
    if (!metaById[el.value] && label) {
      metaById[el.value] = { plate: label.dataset.plate || el.value, driver: label.dataset.driver || '' };
    }
  });

  function getSelectedIds() {
    return new Set(hiddenChecks.filter((c) => c.checked).map((c) => c.value));
  }

  function syncOptionChecksFromHidden() {
    const selected = getSelectedIds();
    optionChecks.forEach((c) => { c.checked = selected.has(c.value); });
  }

  function syncHiddenFromOptions() {
    const selected = new Set(optionChecks.filter((c) => c.checked).map((c) => c.value));
    hiddenChecks.forEach((c) => { c.checked = selected.has(c.value); });
    renderChips();
  }

  function renderChips() {
    const selected = getSelectedIds();
    chipsContainer.innerHTML = '';
    const ids = Array.from(selected);
    if (countEl) countEl.textContent = String(ids.length);
    if (placeholder) placeholder.style.display = ids.length ? 'none' : '';
    if (!ids.length) {
      field.style.background = '#f8fafc';
      return;
    }
    field.style.background = 'white';
    ids.forEach((id) => {
      const meta = metaById[id] || { plate: id, driver: '' };
      const chip = document.createElement('span');
      chip.className = 'inline-flex items-center gap-1.5 px-2.5 py-1 rounded-full bg-[#e6f5f2] border border-[#0f766e]/20 text-xs font-semibold text-[#0d5f59]';
      const label = meta.driver ? meta.plate + ' — ' + meta.driver : meta.plate;
      chip.innerHTML = '<span>' + label + '</span><button type="button" data-remove-id="' + id + '" class="w-4 h-4 rounded-full bg-white border border-[#0f766e]/20 text-[#0f766e] flex items-center justify-center text-[10px] leading-none hover:bg-[#0f766e] hover:text-white" aria-label="hapus">×</button>';
      chipsContainer.appendChild(chip);
    });
  }

  function filterList() {
    const q = (searchInput ? searchInput.value : '').trim().toLowerCase();
    let visible = 0;
    optionLabels.forEach((label) => {
      const plate = (label.dataset.plate || '').toLowerCase();
      const driver = (label.dataset.driver || '').toLowerCase();
      const match = !q || plate.includes(q) || driver.includes(q);
      label.style.display = match ? '' : 'none';
      if (match) visible++;
    });
    if (emptyEl) emptyEl.classList.toggle('hidden', visible !== 0);
  }

  function openModal() {
    syncOptionChecksFromHidden();
    if (searchInput) { searchInput.value = ''; filterList(); }
    modal.classList.remove('hidden');
    document.body.style.overflow = 'hidden';
    setTimeout(() => searchInput && searchInput.focus(), 50);
  }

  function closeModal() {
    modal.classList.add('hidden');
    document.body.style.overflow = '';
    syncHiddenFromOptions();
  }

  field.addEventListener('click', openModal);
  backdrop && backdrop.addEventListener('click', closeModal);
  okBtn && okBtn.addEventListener('click', closeModal);
  document.addEventListener('keydown', (e) => {
    if (e.key === 'Escape' && !modal.classList.contains('hidden')) closeModal();
  });

  if (searchInput) searchInput.addEventListener('input', filterList);
  optionChecks.forEach((c) => c.addEventListener('change', () => {
    // keep hidden in sync live for count preview (optional)
    const id = c.value;
    const hidden = hiddenChecks.find((h) => h.value === id);
    if (hidden) hidden.checked = c.checked;
    renderChips();
  }));

  chipsContainer.addEventListener('click', (e) => {
    const btn = e.target.closest('button[data-remove-id]');
    if (!btn) return;
    e.stopPropagation();
    const id = btn.dataset.removeId;
    const hidden = hiddenChecks.find((h) => h.value === id);
    const opt = optionChecks.find((c) => c.value === id);
    if (hidden) hidden.checked = false;
    if (opt) opt.checked = false;
    renderChips();
  });

  // initial render
  renderChips();
})();
