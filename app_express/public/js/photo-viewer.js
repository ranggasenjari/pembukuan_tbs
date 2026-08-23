(function () {
  const asideImg = document.getElementById('bon-photo');
  const mobileImg = document.getElementById('bon-photo-sm');
  const asidePlaceholder = document.getElementById('bon-photo-placeholder');
  const mobilePlaceholder = document.getElementById('bon-photo-placeholder-sm');

  let lightbox = null;
  let lbImg = null;
  let scale = 1;
  let tx = 0;
  let ty = 0;
  let pinchStartDist = 0;
  let moveRef = null;

  function applyTransform() {
    if (!lbImg) return;
    lbImg.style.transform = `translate(${tx}px, ${ty}px) scale(${scale})`;
  }

  function resetView() {
    scale = 1;
    tx = 0;
    ty = 0;
    applyTransform();
  }

  function ensureLightbox() {
    if (lightbox) return;
    lightbox = document.createElement('div');
    lightbox.id = 'bon-photo-lightbox';
    lightbox.innerHTML = `
      <div class="pb-toolbar">
        <button type="button" class="pb-tool-btn" data-pb-action="zoomout" title="Perkecil">−</button>
        <span class="pb-zoom-label">100%</span>
        <button type="button" class="pb-tool-btn" data-pb-action="zoomin" title="Perbesar">+</button>
        <button type="button" class="pb-tool-btn" data-pb-action="reset" title="Reset">1:1</button>
        <button type="button" class="pb-tool-btn pb-close" data-pb-action="close" title="Tutup">✕</button>
      </div>
      <img id="bon-photo-lightbox-img" alt="Foto bon">`;
    document.body.appendChild(lightbox);

    lbImg = lightbox.querySelector('#bon-photo-lightbox-img');

    const updateZoomLabel = () => {
      const label = lightbox.querySelector('.pb-zoom-label');
      if (label) label.textContent = Math.round(scale * 100) + '%';
    };
    const zoomBy = (factor, cx, cy) => {
      const rect = lbImg.getBoundingClientRect();
      const ox = cx == null ? rect.width / 2 : cx - rect.left;
      const oy = cy == null ? rect.height / 2 : cy - rect.top;
      const next = Math.min(5, Math.max(0.5, scale * factor));
      const ratio = next / scale;
      tx = ox - ratio * (ox - tx);
      ty = oy - ratio * (oy - ty);
      scale = next;
      applyTransform();
      updateZoomLabel();
    };

    lightbox.addEventListener('click', (e) => {
      if (e.target === lightbox) close();
    });

    lightbox.addEventListener('wheel', (e) => {
      e.preventDefault();
      zoomBy(e.deltaY < 0 ? 1.12 : 1 / 1.12);
    }, { passive: false });

    let touchMode = null;
    let touchRef = null;
    lightbox.addEventListener('touchstart', (e) => {
      if (e.touches.length === 2) {
        touchMode = 'pinch';
        const [a, b] = [e.touches[0], e.touches[1]];
        pinchStartDist = Math.hypot(b.clientX - a.clientX, b.clientY - a.clientY);
      } else if (e.touches.length === 1) {
        touchMode = 'pan';
        touchRef = { x: e.touches[0].clientX, y: e.touches[0].clientY, tx, ty };
      }
    }, { passive: false });

    lightbox.addEventListener('touchmove', (e) => {
      e.preventDefault();
      if (touchMode === 'pinch' && e.touches.length === 2) {
        const [a, b] = [e.touches[0], e.touches[1]];
        const dist = Math.hypot(b.clientX - a.clientX, b.clientY - a.clientY);
        zoomBy(dist / (pinchStartDist || 1), null, null);
        pinchStartDist = dist;
      } else if (touchMode === 'pan' && e.touches.length === 1 && touchRef) {
        tx = touchRef.tx + (e.touches[0].clientX - touchRef.x);
        ty = touchRef.ty + (e.touches[0].clientY - touchRef.y);
        applyTransform();
      }
    }, { passive: false });

    lightbox.addEventListener('touchend', () => {
      touchMode = null;
      touchRef = null;
      pinchStartDist = 0;
    });

    lightbox.addEventListener('mousedown', (e) => {
      moveRef = { startX: e.clientX, startY: e.clientY, tx, ty };
      lightbox.style.cursor = 'grabbing';
      const onMove = (ev) => {
        if (!moveRef) return;
        tx = moveRef.tx + (ev.clientX - moveRef.startX);
        ty = moveRef.ty + (ev.clientY - moveRef.startY);
        applyTransform();
      };
      const onUp = () => {
        moveRef = null;
        lightbox.style.cursor = '';
        window.removeEventListener('mousemove', onMove);
        window.removeEventListener('mouseup', onUp);
      };
      window.addEventListener('mousemove', onMove);
      window.addEventListener('mouseup', onUp);
    });

    lightbox.addEventListener('dblclick', () => {
      if (scale > 1.05) resetView();
      else zoomBy(2, null, null);
    });

    lightbox.querySelectorAll('[data-pb-action]').forEach((btn) => {
      btn.addEventListener('click', () => {
        const action = btn.dataset.pbAction;
        if (action === 'zoomin') zoomBy(1.25, null, null);
        else if (action === 'zoomout') zoomBy(1 / 1.25, null, null);
        else if (action === 'reset') resetView();
        else if (action === 'close') close();
      });
    });

    document.addEventListener('keydown', (e) => {
      if (e.key === 'Escape' && lightbox && !lightbox.classList.contains('hidden')) close();
    });
  }

  function open(src) {
    ensureLightbox();
    lbImg.src = src;
    lightbox.classList.remove('hidden');
    resetView();
    document.body.style.overflow = 'hidden';
  }

  function close() {
    if (!lightbox) return;
    lightbox.classList.add('hidden');
    document.body.style.overflow = '';
  }

  window.updateBonPhoto = function (src) {
    const url = src || null;
    [asideImg, mobileImg].forEach((img) => {
      if (!img) return;
      if (url) {
        img.src = url;
        img.classList.remove('hidden');
      } else {
        img.removeAttribute('src');
        img.classList.add('hidden');
      }
    });
    if (asidePlaceholder) asidePlaceholder.classList.toggle('hidden', Boolean(url));
    if (mobilePlaceholder) mobilePlaceholder.classList.toggle('hidden', Boolean(url));
    if (lightbox && url && !lightbox.classList.contains('hidden')) {
      lbImg.src = url;
    }
  };

  document.addEventListener('click', (e) => {
    const img = e.target.closest('.bon-photo-clickable');
    if (img && img.currentSrc && !img.classList.contains('hidden')) open(img.currentSrc);
  });

  document.addEventListener('DOMContentLoaded', () => {
    const fileInput = document.getElementById('bon-image');
    fileInput?.addEventListener('change', () => {
      const file = fileInput.files && fileInput.files[0];
      if (file) window.updateBonPhoto(URL.createObjectURL(file));
    });
    if (window.BON_INITIAL_IMAGE && typeof window.updateBonPhoto === 'function') {
      window.updateBonPhoto(window.BON_INITIAL_IMAGE);
    }
  });
})();