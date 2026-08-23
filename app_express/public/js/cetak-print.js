(function () {
  const dialog = document.getElementById('print-status-dialog');
  if (!dialog) return;

  const statusBox = document.getElementById('print-modal-status');
  const statusText = document.getElementById('print-modal-text');
  const filenameEl = document.getElementById('print-filename');
  const jobIdEl = document.getElementById('print-job-id');
  const paperEl = document.getElementById('print-paper');
  const lpstatEl = document.getElementById('print-lpstat');
  const activeJobsEl = document.getElementById('print-active-jobs');
  const closeBtn = document.getElementById('close-print-dialog');
  const confirmBtn = document.getElementById('confirm-print');

  let pollTimer = null;
  let activeRequestId = null;
  let pendingPrint = null;
  let printing = false;

  function setStatus(state, text) {
    statusBox.classList.toggle('is-sending', state === 'sending');
    statusBox.classList.toggle('is-success', state === 'success');
    statusBox.classList.toggle('is-error', state === 'error');
    statusText.textContent = text;
  }

  function setConfirmVisible(visible) {
    if (!confirmBtn) return;
    confirmBtn.style.display = visible ? '' : 'none';
    if (visible) confirmBtn.disabled = false;
  }

  function stopPolling() {
    if (pollTimer) {
      clearInterval(pollTimer);
      pollTimer = null;
    }
  }

  function setLine(el, value) {
    el.textContent = value || '-';
  }

  async function pollStatus(url) {
    const requestId = activeRequestId;
    try {
      const response = await fetch(url, { headers: { Accept: 'application/json' } });
      const result = await response.json().catch(() => ({}));
      if (!response.ok || !result.ok || requestId !== activeRequestId) return;

      const status = result.status || {};
      const lpstat = status.lpstat || '';
      const activeJobs = status.activeJobs || '';

      setLine(lpstatEl, lpstat || 'Printer tidak tersedia.');
      const activeLines = activeJobs.split('\n').filter((line) => line.trim());
      setLine(activeJobsEl, activeLines.length ? activeLines.join(' · ') : 'Tidak ada job aktif.');

      if (activeLines.length > 0) {
        setStatus('sending', 'Sedang mencetak...');
      } else if (/disabled|stopped|not ready/i.test(lpstat)) {
        setStatus('error', 'Printer tidak siap (disabled/stopped).');
      } else if (/idle/i.test(lpstat)) {
        setStatus('success', 'Cetak selesai — printer idle.');
      } else {
        setStatus('success', 'Job tidak aktif lagi.');
      }
    } catch (_) {
      if (requestId !== activeRequestId) return;
      setStatus('sending', 'Menunggu status printer...');
    }
  }

  async function checkPrinter() {
    if (!pendingPrint) return;
    setStatus('sending', 'Memeriksa status printer...');
    setConfirmVisible(false);

    try {
      const response = await fetch(pendingPrint.statusUrl, { headers: { Accept: 'application/json' } });
      const result = await response.json().catch(() => ({}));
      if (!response.ok || !result.ok) {
        throw new Error(result.error || 'Server printer menolak pemeriksaan.');
      }

      const status = result.status || {};
      const lpstat = status.lpstat || '';
      const activeJobs = status.activeJobs || '';

      setLine(filenameEl, pendingPrint.filename);
      setLine(lpstatEl, lpstat || 'Printer tidak tersedia.');
      const activeLines = activeJobs.split('\n').filter((line) => line.trim());
      setLine(activeJobsEl, activeLines.length ? activeLines.join(' · ') : 'Tidak ada job aktif.');

      if (/disabled|stopped|not ready/i.test(lpstat)) {
        setStatus('error', 'Printer sedang tidak aktif/off. Periksa printer lalu coba lagi.');
        return;
      }

      setStatus('success', 'Printer dan server siap. Cetak dokumen ini ke printer?');
      setConfirmVisible(true);
    } catch (error) {
      setStatus('error', 'Printer tidak terhubung: ' + error.message);
    }
  }

  async function startPrint(url, statusUrl) {
    setLine(jobIdEl, null);
    setLine(paperEl, null);
    setStatus('sending', 'Mengirim PDF ke server printer...');

    try {
      const response = await fetch(url, { method: 'POST', headers: { Accept: 'application/json' } });
      const result = await response.json().catch(() => ({}));
      if (!response.ok || !result.ok) {
        throw new Error(result.error || 'Gagal mengirim ke server printer.');
      }

      setLine(jobIdEl, result.requestId || result.jobId || '-');
      setLine(paperEl, result.paperLabel || 'Folio / Legal penuh');
      setStatus('success', 'Job sudah dikirim ke CUPS.');
      printing = false;
      activeRequestId = `${Date.now()}`;
      stopPolling();
      pollTimer = setInterval(() => pollStatus(statusUrl), 5000);
    } catch (error) {
      printing = false;
      setStatus('error', error.message || 'Gagal mengirim ke server printer.');
    }
  }

  function onPrintConfirmed() {
    if (!pendingPrint || printing) return;
    printing = true;
    setConfirmVisible(false);
    startPrint(pendingPrint.url, pendingPrint.statusUrl);
  }

  function resetView() {
    stopPolling();
    activeRequestId = null;
    printing = false;
    pendingPrint = null;
    setConfirmVisible(false);
  }

  document.querySelectorAll('[data-print-pdf]').forEach((button) => {
    button.addEventListener('click', () => {
      const url = button.dataset.printPdf;
      const statusUrl = button.dataset.printStatus;
      if (!url) return;

      setLine(filenameEl, button.dataset.filename || 'cetakan-harian.pdf');
      setLine(jobIdEl, null);
      setLine(paperEl, null);
      setLine(lpstatEl, null);
      setLine(activeJobsEl, null);

      pendingPrint = { url, statusUrl, filename: button.dataset.filename || 'cetakan-harian.pdf' };
      dialog.showModal();
      checkPrinter();
    });
  });

  confirmBtn?.addEventListener('click', onPrintConfirmed);
  closeBtn?.addEventListener('click', () => {
    resetView();
    dialog.close();
  });
  dialog.addEventListener('close', resetView);
})();