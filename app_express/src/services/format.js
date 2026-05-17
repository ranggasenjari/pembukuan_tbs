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

module.exports = { currency, date, dateInput, dateTime, number, statusLabel };
