document.getElementById('add-payment-relation-account')?.addEventListener('click', () => {
  const wrapper = document.createElement('div');
  wrapper.className = 'payment-relation-account-row grid gap-3 md:grid-cols-[1fr_1fr_1fr_48px]';
  wrapper.innerHTML = `
    <input name="bank_name" class="form-input uppercase" placeholder="Nama Bank">
    <input name="account_number" class="form-input" placeholder="No Rekening">
    <input name="account_name" class="form-input uppercase" placeholder="Nama Rekening">
    <button type="button" class="remove-payment-relation-account rounded-lg bg-rose-50 text-rose-700">x</button>
  `;
  document.getElementById('payment-relation-accounts').appendChild(wrapper);
});

document.addEventListener('click', (event) => {
  if (event.target.classList.contains('remove-payment-relation-account')) {
    event.target.closest('.payment-relation-account-row')?.remove();
  }
});
