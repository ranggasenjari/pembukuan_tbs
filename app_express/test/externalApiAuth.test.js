const { env } = require('../src/config/env');
const { isValidApiKey, requireExternalApiKey } = require('../src/middleware/externalApiAuth');

describe('external API auth', () => {
  const originalKey = env.externalApiKey;

  afterEach(() => {
    env.externalApiKey = originalKey;
  });

  it('validates API keys with exact matching only', () => {
    expect(isValidApiKey('secret-key', 'secret-key')).toBe(true);
    expect(isValidApiKey('secret-key', 'other-key')).toBe(false);
    expect(isValidApiKey('', 'secret-key')).toBe(false);
  });

  it('passes request with a valid X-API-Key header', () => {
    env.externalApiKey = 'secret-key';
    const req = { get: vi.fn(() => 'secret-key') };
    const next = vi.fn();

    requireExternalApiKey(req, {}, next);

    expect(next).toHaveBeenCalledWith();
  });

  it('rejects request with an invalid X-API-Key header', () => {
    env.externalApiKey = 'secret-key';
    const req = { get: vi.fn(() => 'wrong-key') };
    const next = vi.fn();

    requireExternalApiKey(req, {}, next);

    const error = next.mock.calls[0][0];
    expect(error.status).toBe(401);
    expect(error.code).toBe('UNAUTHORIZED');
  });
});
