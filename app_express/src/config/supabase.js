const { createClient } = require('@supabase/supabase-js');
const { env } = require('./env');

function baseOptions(token) {
  return {
    db: { schema: env.supabaseSchema },
    auth: {
      persistSession: false,
      autoRefreshToken: false,
      detectSessionInUrl: false
    },
    global: token
      ? {
          headers: {
            Authorization: `Bearer ${token}`
          }
        }
      : undefined
  };
}

function createAnonClient() {
  return createClient(env.supabaseUrl, env.supabaseAnonKey, baseOptions());
}

function createUserClient(accessToken) {
  return createClient(env.supabaseUrl, env.supabaseAnonKey, baseOptions(accessToken));
}

function createServiceClient() {
  if (!env.supabaseUrl || !env.supabaseServiceRoleKey) return null;
  return createClient(env.supabaseUrl, env.supabaseServiceRoleKey, baseOptions());
}

module.exports = { createAnonClient, createServiceClient, createUserClient };
