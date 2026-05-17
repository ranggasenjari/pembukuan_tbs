const { createAnonClient, createUserClient } = require('../config/supabase');

function isExpiringSoon(session) {
  if (!session?.expires_at) return false;
  return session.expires_at * 1000 - Date.now() < 60_000;
}

async function refreshIfNeeded(req) {
  const stored = req.session.supabase;
  if (!stored?.refresh_token || !isExpiringSoon(stored)) return stored;

  const anon = createAnonClient();
  const { data, error } = await anon.auth.refreshSession({
    refresh_token: stored.refresh_token
  });

  if (error || !data.session) {
    req.session.destroy(() => {});
    return null;
  }

  req.session.supabase = {
    access_token: data.session.access_token,
    refresh_token: data.session.refresh_token,
    expires_at: data.session.expires_at,
    user: data.user
  };

  return req.session.supabase;
}

async function requireAuth(req, res, next) {
  try {
    const stored = await refreshIfNeeded(req);
    if (!stored?.access_token) {
      return res.redirect('/login');
    }

    req.supabase = createUserClient(stored.access_token);
    req.currentUser = stored.user;
    res.locals.currentUser = stored.user;
    return next();
  } catch (error) {
    return next(error);
  }
}

function redirectIfAuthenticated(req, res, next) {
  if (req.session.supabase?.access_token) return res.redirect('/dashboard');
  return next();
}

module.exports = { requireAuth, redirectIfAuthenticated };
