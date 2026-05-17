function formatCurrency(value) {
  return new Intl.NumberFormat('id-ID', {
    style: 'currency',
    currency: 'IDR',
    maximumFractionDigits: 0
  }).format(value);
}

function updateLoginClock() {
  const now = new Date();
  const clock = document.querySelector('[data-login-clock]');
  const date = document.querySelector('[data-login-date]');
  if (clock) {
    clock.textContent = new Intl.DateTimeFormat('id-ID', {
      hour: '2-digit',
      minute: '2-digit'
    }).format(now);
  }
  if (date) {
    date.textContent = new Intl.DateTimeFormat('id-ID', {
      weekday: 'long',
      day: '2-digit',
      month: 'long'
    }).format(now);
  }
}

function animateLoginMetrics() {
  const balance = document.querySelector('[data-login-pulse="balance"]');
  const bons = document.querySelector('[data-login-pulse="bons"]');
  const margin = document.querySelector('[data-login-pulse="margin"]');
  const tick = Math.floor(Date.now() / 1800);
  if (balance) balance.textContent = formatCurrency(185000000 + (tick % 9) * 1250000);
  if (bons) bons.textContent = String(18 + (tick % 4));
  if (margin) margin.textContent = formatCurrency(12750000 + (tick % 6) * 420000);
}

updateLoginClock();
animateLoginMetrics();
setInterval(updateLoginClock, 1000);
setInterval(animateLoginMetrics, 1800);
