const notaFmt = new Intl.NumberFormat('id-ID', { style: 'currency', currency: 'IDR', maximumFractionDigits: 0 });

function updateNotaTotal() {
  const total = [...document.querySelectorAll('input[name="bon_ids"]:checked')]
    .reduce((sum, input) => sum + (Number(input.dataset.total) || 0), 0);
  document.getElementById('nota-total').textContent = notaFmt.format(total);
}

document.addEventListener('change', (event) => {
  if (event.target.name === 'bon_ids') updateNotaTotal();
});

updateNotaTotal();
