const { createAnonClient, createUserClient } = require('../config/supabase');
const { env } = require('../config/env');
const { apiError } = require('./apiResponse');

function isExpiringSoon(session) {
  if (!session?.expires_at) return true;
  return session.expires_at * 1000 - Date.now() < 60_000;
}

function createSystemSupabaseManager(dependencies) {
  const deps = dependencies || { createAnonClient, createUserClient, env };
  let cachedSession = null;
  let pendingSession = null;

  function assertConfigured() {
    if (!deps.env.supabaseApiUserEmail || !deps.env.supabaseApiUserPassword) {
      throw apiError(
        503,
        'API_USER_NOT_CONFIGURED',
        'SUPABASE_API_USER_EMAIL dan SUPABASE_API_USER_PASSWORD belum dikonfigurasi.'
      );
    }
  }

  async function signIn() {
    assertConfigured();
    const anon = deps.createAnonClient();
    const { data, error } = await anon.auth.signInWithPassword({
      email: deps.env.supabaseApiUserEmail,
      password: deps.env.supabaseApiUserPassword
    });

    if (error || !data?.session) {
      throw apiError(503, 'API_USER_LOGIN_FAILED', 'Gagal login sebagai user sistem Supabase.', error?.message);
    }

    cachedSession = {
      access_token: data.session.access_token,
      refresh_token: data.session.refresh_token,
      expires_at: data.session.expires_at,
      user: data.user
    };
    return cachedSession;
  }

  async function refresh() {
    if (!cachedSession?.refresh_token) return signIn();

    const anon = deps.createAnonClient();
    const { data, error } = await anon.auth.refreshSession({
      refresh_token: cachedSession.refresh_token
    });

    if (error || !data?.session) {
      cachedSession = null;
      return signIn();
    }

    cachedSession = {
      access_token: data.session.access_token,
      refresh_token: data.session.refresh_token,
      expires_at: data.session.expires_at,
      user: data.user
    };
    return cachedSession;
  }

  async function getSystemSession() {
    if (cachedSession && !isExpiringSoon(cachedSession)) return cachedSession;
    if (!pendingSession) {
      pendingSession = (cachedSession ? refresh() : signIn()).finally(() => {
        pendingSession = null;
      });
    }
    return pendingSession;
  }

  async function getSystemSupabaseClient() {
    const session = await getSystemSession();
    return deps.createUserClient(session.access_token);
  }

  function clearSystemSession() {
    cachedSession = null;
    pendingSession = null;
  }

  return {
    clearSystemSession,
    getSystemSession,
    getSystemSupabaseClient
  };
}

const manager = createSystemSupabaseManager();

module.exports = {
  clearSystemSession: manager.clearSystemSession,
  createSystemSupabaseManager,
  getSystemSession: manager.getSystemSession,
  getSystemSupabaseClient: manager.getSystemSupabaseClient,
  isExpiringSoon
};
