const rupiah = new Intl.NumberFormat('id-ID', { style: 'currency', currency: 'IDR', maximumFractionDigits: 0 });

function num(name) {
  const input = document.querySelector(`[name="${name}"]`);
  return Number(String(input?.value || '0').replace(/[^\d.-]/g, '')) || 0;
}

function setValue(name, value) {
  const input = document.querySelector(`[name="${name}"]`);
  if (input && input.value !== String(value)) input.value = String(value);
}

function calculate() {
  const netto1 = num('netto_1');
  const netto2 = num('netto_2');
  const price = num('price');
  const subtotal = netto2 * price;
  const pph = Math.floor(0.0025 * subtotal);
  const uangMinum = netto2 > 8000 ? 20000 : 10000;

  setValue('pph', pph);
  setValue('uang_minum', uangMinum);

  const dynamic = [...document.querySelectorAll('.deduction-amount')].reduce((sum, input) => sum + (Number(input.value) || 0), 0);
  const totalDeduction = num('dp') + (num('biaya_bongkar') * netto1) + num('bp_colt') + num('pph') + num('uang_minum') + dynamic;
  const total = subtotal - totalDeduction;

  document.getElementById('subtotal-display').textContent = rupiah.format(subtotal);
  document.getElementById('deduction-display').textContent = rupiah.format(totalDeduction);
  document.getElementById('total-display').textContent = rupiah.format(total);
}

document.addEventListener('input', (event) => {
  if (event.target.classList.contains('bon-calc')) calculate();
});

document.getElementById('add-deduction')?.addEventListener('click', () => {
  const wrapper = document.createElement('div');
  wrapper.className = 'deduction-row grid gap-3 md:grid-cols-[1fr_220px_48px]';
  wrapper.innerHTML = `
    <input name="deduction_label" class="form-input" placeholder="Nama potongan">
    <input name="deduction_amount" value="0" type="number" class="form-input bon-calc deduction-amount">
    <button type="button" class="remove-deduction rounded-lg bg-rose-50 text-rose-700">×</button>
  `;
  document.getElementById('deductions').appendChild(wrapper);
});

document.addEventListener('click', (event) => {
  if (event.target.classList.contains('remove-deduction')) {
    event.target.closest('.deduction-row')?.remove();
    calculate();
  }
});

document.getElementById('ocr-button')?.addEventListener('click', async () => {
  const fileInput = document.getElementById('bon-image');
  const status = document.getElementById('ocr-status');
  if (!fileInput.files.length) {
    status.textContent = 'Pilih gambar terlebih dahulu.';
    return;
  }

  const formData = new FormData();
  formData.append('file', fileInput.files[0]);
  status.textContent = 'Membaca OCR...';
  try {
    const response = await fetch('/api/ocr/bon', { method: 'POST', body: formData });
    const payload = await response.json();
    if (!response.ok) throw new Error(payload.error || 'OCR gagal');
    const data = payload.data || {};
    ['ticket_number', 'bon_date', 'plate_number', 'driver_name', 'relation_name', 'fruit_origin', 'netto_1', 'netto_2'].forEach((key) => {
      const input = document.querySelector(`[name="${key}"]`);
      if (input && data[key] !== undefined && data[key] !== null) input.value = data[key];
    });
    calculate();
    status.textContent = 'Data bon berhasil terbaca.';
  } catch (error) {
    status.textContent = error.message;
  }
});

calculate();
