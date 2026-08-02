function addRow(wrapperId, className, html) {
  const wrapper = document.createElement('div');
  wrapper.className = `${className} grid gap-3 md:grid-cols-[1fr_1fr_48px]`;
  wrapper.innerHTML = html;
  document.getElementById(wrapperId).appendChild(wrapper);
}

document.getElementById('add-account')?.addEventListener('click', () => {
  addRow('accounts', 'account-row', `
    <input name="account_name" class="form-input uppercase" placeholder="Nama Rekening">
    <input name="account_number" class="form-input" placeholder="No Rekening">
    <button type="button" class="remove-account rounded-lg bg-rose-50 text-rose-700">x</button>
  `);
});

document.getElementById('add-driver')?.addEventListener('click', () => {
  addRow('drivers', 'driver-row', `
    <input name="driver_name" class="form-input uppercase" placeholder="Nama Supir">
    <input name="plate_number" class="form-input uppercase" placeholder="Nomor Plat">
    <button type="button" class="remove-driver rounded-lg bg-rose-50 text-rose-700">x</button>
  `);
});

document.addEventListener('click', (event) => {
  if (event.target.classList.contains('remove-account')) {
    event.target.closest('.account-row')?.remove();
  }
  if (event.target.classList.contains('remove-driver')) {
    event.target.closest('.driver-row')?.remove();
  }
});
