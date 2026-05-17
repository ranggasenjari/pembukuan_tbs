document.querySelectorAll('[data-share-pdf]').forEach((button) => {
  button.addEventListener('click', async () => {
    const url = button.dataset.sharePdf;
    const title = button.dataset.shareTitle || 'Nota PDF';
    try {
      const response = await fetch(url);
      const blob = await response.blob();
      const file = new File([blob], `${title}.pdf`, { type: 'application/pdf' });
      if (navigator.canShare && navigator.canShare({ files: [file] })) {
        await navigator.share({ title, files: [file] });
      } else {
        window.open(url, '_blank');
      }
    } catch {
      window.open(url, '_blank');
    }
  });
});
