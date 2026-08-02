const notaFmt = new Intl.NumberFormat('id-ID', { style: 'currency', currency: 'IDR', maximumFractionDigits: 0 });

function updateNotaTotal() {
  const total = [...document.querySelectorAll('input[name="bon_ids"]:checked')]
    .reduce((sum, input) => sum + (Number(input.dataset.total) || 0), 0);
  document.getElementById('nota-total').textContent = notaFmt.format(total);
}

document.addEventListener('change', (event) => {
  if (event.target.name === 'bon_ids') updateNotaTotal();
  if (event.target.name === 'relation_agent_id') renderRelationInfo();
});

function renderRelationInfo() {
  const container = document.getElementById('relation-info');
  const relationId = document.querySelector('[name="relation_agent_id"]')?.value;
  const relation = (window.RELATION_AGENTS || []).find((item) => item.id === relationId);
  if (!container) return;
  if (!relation) {
    container.innerHTML = '<span class="text-slate-500">Pilih relasi untuk melihat alamat dan rekening.</span>';
    return;
  }
  const accounts = relation.relation_agent_accounts || [];
  container.innerHTML = `
    <strong class="block">${relation.name || '-'}</strong>
    <span class="block">${relation.address || '-'}</span>
    <div class="mt-2">${accounts.length ? accounts.map((account) => `<span class="block">${account.account_name || '-'} - ${account.account_number || '-'}</span>`).join('') : '<span class="text-slate-500">Belum ada rekening.</span>'}</div>
  `;
}

updateNotaTotal();
renderRelationInfo();
