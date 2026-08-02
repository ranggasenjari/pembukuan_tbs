const { toInt } = require('./calculations');

function bonSpsiAmount(bon) {
  if (bon.spsi_amount !== null && bon.spsi_amount !== undefined) return toInt(bon.spsi_amount);
  return toInt(bon.biaya_bongkar) * toInt(bon.netto_1);
}

function formatPhone(value) {
  const s = String(value || '').replace(/\D/g, '');
  if (s.startsWith('0')) return '+62' + s.slice(1);
  if (s.startsWith('62')) return '+' + s;
  return s || '-';
}

function money(value) {
  return new Intl.NumberFormat('id-ID', { style: 'currency', currency: 'IDR', maximumFractionDigits: 0 }).format(toInt(value));
}

function buildPaymentInfoMessage(paymentRelation) {
  const lines = [];
  lines.push('Relasi:');
  lines.push(`*${paymentRelation.name}* | ${formatPhone(paymentRelation.contact)}`);
  lines.push('Rek:');
  (paymentRelation.payment_relation_accounts || []).forEach((a) => {
    lines.push(`- ${a.bank_name || '-'} | ${a.account_number || '-'} | ${a.account_name || '-'}`);
  });
  const notes = paymentRelation.notes || paymentRelation.address || '';
  if (notes && notes !== '-' && notes.trim()) {
    lines.push('Catatan:');
    lines.push(`__${notes}__`);
  }
  return lines.join('\n');
}

function buildNotaWhatsappMessage(nota, bons = []) {
  const lines = [
    `*${nota.invoice_number || ''}*`.trim(),
    `Relasi: ${nota.relation_agents?.name || nota.recipient_name || '-'}`,
    ''
  ];

  let grandTotal = 0;
  let totalDp = 0;
  bons.forEach((bon, index) => {
    const bruto = toInt(bon.netto_2) * toInt(bon.price);
    const spsi = bonSpsiAmount(bon);
    const bonDp = toInt(bon.dp);
    const bonTotalBeforeDp = toInt(bon.total) + bonDp;
    grandTotal += bonTotalBeforeDp;
    totalDp += bonDp;

    lines.push(`*${index + 1}. ${bon.plate_number || '-'}* — ${bon.driver_name || '-'}`);
    lines.push(`   ${toInt(bon.netto_2)} kg x ${money(bon.price)}`);
    lines.push(`   *${money(bruto)}*`);
    lines.push('');

    lines.push('   *Potongan:*');
    if (spsi > 0) lines.push(`      SPSI: ${money(spsi)}`);
    if (toInt(bon.bp_colt) > 0) lines.push(`      BP/Colt: ${money(bon.bp_colt)}`);
    if (toInt(bon.pph) > 0) lines.push(`      PPh: ${money(bon.pph)}`);
    if (toInt(bon.uang_minum) > 0) lines.push(`      Uang Minum: ${money(bon.uang_minum)}`);
    (bon.bon_deductions || []).forEach((d) => {
      if (toInt(d.amount) > 0) lines.push(`      ${d.label || 'Potongan'}: ${money(d.amount)}`);
    });
    lines.push(`   *Total bon: ${money(bonTotalBeforeDp)}*`);
    lines.push('');
  });

  lines.push(`*TOTAL NOTA: ${money(grandTotal)}*`);
  if (totalDp > 0) {
    lines.push(`DP / Panjar: ${money(totalDp)}`);
    lines.push(`*Total Akhir: ${money(grandTotal - totalDp)}*`);
  }
  return lines.join('\n');
}

module.exports = {
  bonSpsiAmount,
  buildNotaWhatsappMessage,
  buildPaymentInfoMessage
};
