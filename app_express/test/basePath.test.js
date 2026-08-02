describe('base path support', () => {
  const originalBasePath = process.env.BASE_PATH;

  afterEach(() => {
    if (originalBasePath === undefined) delete process.env.BASE_PATH;
    else process.env.BASE_PATH = originalBasePath;
    vi.resetModules();
  });

  it('prefixes redirects and rendered asset/form URLs when BASE_PATH is configured', async () => {
    process.env.BASE_PATH = '/bon/';
    vi.resetModules();

    const request = require('supertest');
    const app = require('../src/app');

    const redirectResponse = await request(app).get('/bon/dashboard');
    expect(redirectResponse.status).toBe(302);
    expect(redirectResponse.headers.location).toBe('/bon/login');

    const loginResponse = await request(app).get('/bon/login');
    expect(loginResponse.status).toBe(200);
    expect(loginResponse.text).toContain('href="/bon/css/app.css"');
    expect(loginResponse.text).toContain('action="/bon/login"');
    expect(loginResponse.text).toContain('src="/bon/js/login.js"');
  });

  it('still serves routes from root for proxies that strip the prefix upstream', async () => {
    process.env.BASE_PATH = '/bon';
    vi.resetModules();

    const request = require('supertest');
    const app = require('../src/app');

    const response = await request(app).get('/dashboard');
    expect(response.status).toBe(302);
    expect(response.headers.location).toBe('/bon/login');
  });
});
