const { createSystemSupabaseManager } = require('../src/services/systemSupabase');

describe('system Supabase manager', () => {
  it('signs in as the configured system user and reuses the cached session', async () => {
    const future = Math.floor(Date.now() / 1000) + 3600;
    const anon = {
      auth: {
        signInWithPassword: vi.fn().mockResolvedValue({
          data: {
            session: { access_token: 'token-1', refresh_token: 'refresh-1', expires_at: future },
            user: { id: 'api-user' }
          },
          error: null
        }),
        refreshSession: vi.fn()
      }
    };
    const createUserClient = vi.fn((token) => ({ token }));
    const manager = createSystemSupabaseManager({
      createAnonClient: vi.fn(() => anon),
      createUserClient,
      env: {
        supabaseApiUserEmail: 'api@example.com',
        supabaseApiUserPassword: 'secret'
      }
    });

    const first = await manager.getSystemSupabaseClient();
    const second = await manager.getSystemSupabaseClient();

    expect(anon.auth.signInWithPassword).toHaveBeenCalledTimes(1);
    expect(anon.auth.refreshSession).not.toHaveBeenCalled();
    expect(first.token).toBe('token-1');
    expect(second.token).toBe('token-1');
    expect(createUserClient).toHaveBeenCalledTimes(2);
  });

  it('refreshes an expiring cached session before creating the next client', async () => {
    const past = Math.floor(Date.now() / 1000) - 60;
    const future = Math.floor(Date.now() / 1000) + 3600;
    const anon = {
      auth: {
        signInWithPassword: vi.fn().mockResolvedValue({
          data: {
            session: { access_token: 'old-token', refresh_token: 'refresh-1', expires_at: past },
            user: { id: 'api-user' }
          },
          error: null
        }),
        refreshSession: vi.fn().mockResolvedValue({
          data: {
            session: { access_token: 'new-token', refresh_token: 'refresh-2', expires_at: future },
            user: { id: 'api-user' }
          },
          error: null
        })
      }
    };
    const manager = createSystemSupabaseManager({
      createAnonClient: vi.fn(() => anon),
      createUserClient: vi.fn((token) => ({ token })),
      env: {
        supabaseApiUserEmail: 'api@example.com',
        supabaseApiUserPassword: 'secret'
      }
    });

    await manager.getSystemSupabaseClient();
    const refreshed = await manager.getSystemSupabaseClient();

    expect(anon.auth.refreshSession).toHaveBeenCalledWith({ refresh_token: 'refresh-1' });
    expect(refreshed.token).toBe('new-token');
  });
});
