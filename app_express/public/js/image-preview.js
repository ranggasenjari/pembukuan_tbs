(function() {
  if (window._imagePreviewInitialized) return;
  window._imagePreviewInitialized = true;

  function injectStyles() {
    if (document.getElementById('image-preview-style')) return;
    const style = document.createElement('style');
    style.id = 'image-preview-style';
    style.textContent = `
      .img-overlay{position:fixed;inset:0;z-index:99999;background:rgba(0,0,0,0.85);display:flex;align-items:center;justify-content:center}
      .img-viewer{max-width:90vw;max-height:90vh;border-radius:8px;box-shadow:0 20px 60px rgba(0,0,0,0.5);cursor:grab;user-select:none;-webkit-user-select:none;transition:transform .05s ease}
      .img-close{position:fixed;top:16px;right:24px;font-size:40px;color:#fff;cursor:pointer;z-index:1;line-height:1;opacity:.7;font-family:serif}
      .img-close:hover{opacity:1}
      .img-rotate{position:fixed;top:16px;right:80px;font-size:32px;color:#fff;cursor:pointer;z-index:1;line-height:1;opacity:.7}
      .img-rotate:hover{opacity:1}
    `;
    document.head.appendChild(style);
  }

  function openPreview(url) {
    injectStyles();
    const overlay = document.createElement('div');
    overlay.className = 'img-overlay';
    overlay.innerHTML = '<span class="img-close">&times;</span><span class="img-rotate">&#x21bb;</span>';
    const img = document.createElement('img');
    img.className = 'img-viewer';
    img.src = url;
    overlay.appendChild(img);
    document.body.appendChild(overlay);

    let scale = 1, ox = 0, oy = 0, angle = 0, dragging = false, startX, startY;

    function update() {
      img.style.transform = `translate(${ox}px,${oy}px) scale(${scale}) rotate(${angle}deg)`;
    }

    overlay.querySelector('.img-close').onclick = () => overlay.remove();
    overlay.querySelector('.img-rotate').onclick = () => { angle = (angle + 90) % 360; update(); };
    overlay.onclick = e => { if (e.target === overlay) overlay.remove(); };

    img.onwheel = e => {
      e.preventDefault();
      const delta = e.deltaY > 0 ? -0.1 : 0.1;
      scale = Math.max(0.3, Math.min(5, scale + delta));
      update();
    };

    img.onmousedown = e => {
      e.preventDefault();
      dragging = true; startX = e.clientX - ox; startY = e.clientY - oy;
      img.style.cursor = 'grabbing';
    };
    document.onmousemove = e => {
      if (!dragging) return;
      ox = e.clientX - startX; oy = e.clientY - startY;
      update();
    };
    document.onmouseup = () => { dragging = false; img.style.cursor = 'grab'; };

    let lastDist = 0;
    img.ontouchstart = e => {
      if (e.touches.length === 2) lastDist = Math.hypot(e.touches[0].clientX - e.touches[1].clientX, e.touches[0].clientY - e.touches[1].clientY);
    };
    img.ontouchmove = e => {
      if (e.touches.length === 2) {
        e.preventDefault();
        const dist = Math.hypot(e.touches[0].clientX - e.touches[1].clientX, e.touches[0].clientY - e.touches[1].clientY);
        scale = Math.max(0.3, Math.min(5, scale * (dist / lastDist)));
        lastDist = dist;
        update();
      }
    };
  }

  // Delegation agar juga mencakup konten yang diperbarui realtime
  document.addEventListener('click', (event) => {
    const btn = event.target.closest('.bon-image-preview');
    if (btn && btn.dataset.url) {
      openPreview(btn.dataset.url);
    }
  });
})();
