const sumFmt = new Intl.NumberFormat('id-ID', { style: 'currency', currency: 'IDR', maximumFractionDigits: 0 });

function updateCheckedTotal() {
  const checked = [...document.querySelectorAll('input[type="checkbox"][data-total]:checked')];
  const total = checked.reduce((sum, input) => sum + (Number(input.dataset.total) || 0), 0);
  const target = document.getElementById('payment-total') || document.getElementById('margin-total');
  if (target) target.textContent = sumFmt.format(total);
}

document.addEventListener('change', (event) => {
  if (event.target.matches('input[type="checkbox"][data-total]')) updateCheckedTotal();
});

updateCheckedTotal();
