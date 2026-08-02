function currency(value) {
  return new Intl.NumberFormat('id-ID', {
    style: 'currency',
    currency: 'IDR',
    maximumFractionDigits: 0
  }).format(Number(value || 0));
}

function number(value) {
  return new Intl.NumberFormat('id-ID').format(Number(value || 0));
}

function date(value) {
  if (!value) return '-';
  return new Intl.DateTimeFormat('id-ID', {
    day: '2-digit',
    month: 'short',
    year: 'numeric'
  }).format(new Date(value));
}

function dateTime(value) {
  if (!value) return '-';
  return new Intl.DateTimeFormat('id-ID', {
    day: '2-digit',
    month: 'short',
    year: 'numeric',
    hour: '2-digit',
    minute: '2-digit'
  }).format(new Date(value));
}

function dateInput(value) {
  if (!value) return new Date().toISOString().slice(0, 10);
  return new Date(value).toISOString().slice(0, 10);
}

function statusLabel(status) {
  const map = {
    BELUM_DIBAYAR: 'Belum Dibayar',
    TERTAGIH: 'Tertagih',
    LUNAS: 'Lunas'
  };
  return map[status] || status || '-';
}

function labelFrom(map, status) {
  return map[status] || statusLabel(status);
}

function descriptionFrom(map, status) {
  return map[status] || '';
}

function bonStatusLabel(status) {
  return labelFrom({
    BELUM_DIBAYAR: 'Belum Dibuat Nota',
    TERTAGIH: 'Menunggu Pembayaran',
    LUNAS: 'Lunas'
  }, status);
}

function bonStatusDescription(status) {
  return descriptionFrom({
    BELUM_DIBAYAR: 'Bon belum masuk nota dan masih bisa diedit atau dihapus.',
    TERTAGIH: 'Bon sudah masuk nota dan menunggu pembayaran atau bukti transfer.',
    LUNAS: 'Bon sudah selesai dibayar.'
  }, status);
}

function notaStatusLabel(status) {
  return labelFrom({
    BELUM_DIBAYAR: 'Belum Terbit / Data Lama',
    TERTAGIH: 'Menunggu Pembayaran',
    LUNAS: 'Lunas'
  }, status);
}

function notaStatusDescription(status) {
  return descriptionFrom({
    BELUM_DIBAYAR: 'Status lama: nota belum ditandai terbit. Jalankan cleanup untuk menormalkan data.',
    TERTAGIH: 'Nota sudah terbit dan menunggu pembayaran atau bukti transfer.',
    LUNAS: 'Nota sudah memiliki pembayaran.'
  }, status);
}

module.exports = {
  bonStatusDescription,
  bonStatusLabel,
  currency,
  date,
  dateInput,
  dateTime,
  notaStatusDescription,
  notaStatusLabel,
  number,
  statusLabel
};
