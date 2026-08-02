function normalizeBasePath(value) {
  const raw = String(value || '').trim();
  if (!raw || raw === '/') return '';
  return `/${raw.replace(/^\/+|\/+$/g, '')}`;
}

function isExternalUrl(path) {
  return /^(?:[a-z][a-z0-9+.-]*:)?\/\//i.test(path) || /^[a-z][a-z0-9+.-]*:/i.test(path);
}

function urlFor(path, basePath = '') {
  const target = String(path || '/');
  const normalizedBase = normalizeBasePath(basePath);

  if (!normalizedBase || isExternalUrl(target) || target.startsWith('#')) return target;
  if (!target.startsWith('/')) return target;
  if (target === normalizedBase || target.startsWith(`${normalizedBase}/`)) return target;
  return `${normalizedBase}${target}`;
}

function stripBasePath(path, basePath = '') {
  const target = String(path || '/');
  const normalizedBase = normalizeBasePath(basePath);
  if (!normalizedBase) return target;
  if (target === normalizedBase) return '/';
  if (target.startsWith(`${normalizedBase}/`)) return target.slice(normalizedBase.length) || '/';
  return target;
}

module.exports = { normalizeBasePath, stripBasePath, urlFor };
