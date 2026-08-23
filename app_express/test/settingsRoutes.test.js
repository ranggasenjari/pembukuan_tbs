const express = require('express');
const request = require('supertest');
const settingsRoutes = require('../src/routes/settingsRoutes');

function makeSupabase(initialValue = {}) {
  const state = {
    row: {
      key: 'ocr',
      value: {
        mode: 'webhook',
        webhook_url: 'https://ocr.test/webhook',
        webhook_key: 'old-webhook-key',
        mistral_api_key: 'old-mistral-key',
        mistral_prompt: 'Prompt',
        mistral_output_schema: '{}',
        ...initialValue
      }
    }
  };

  return {
    state,
    from: vi.fn(() => ({
      select() { return this; },
      eq() { return this; },
      async maybeSingle() { return { data: state.row, error: null }; },
      upsert(payload) {
        state.row = payload;
        return this;
      },
      async single() { return { data: state.row, error: null }; }
    }))
  };
}

function makeApp(supabase = makeSupabase()) {
  const app = express();
  app.use(express.json());
  app.use(express.urlencoded({ extended: true }));
  app.use((req, res, next) => {
    req.supabase = supabase;
    req.flash = vi.fn();
    res.locals.url = (target) => target;
    res.render = (view, locals) => res.json({ view, locals });
    next();
  });
  app.use('/settings', settingsRoutes);
  app.use((error, req, res, next) => {
    res.status(500).json({ error: error.message });
  });
  return { app, supabase };
}

describe('settingsRoutes', () => {
  it('loads default OCR settings on the settings page', async () => {
    const { app, supabase } = makeApp();
    const response = await request(app).get('/settings');

    expect(response.status).toBe(200);
    expect(response.body.view).toBe('settings/index');
    expect(response.body.locals.ocrSettings.mode).toBe('webhook');
    expect(supabase.from).toHaveBeenCalledWith('app_settings');
  });

  it('saves OCR settings and keeps existing secret fields when submitted empty', async () => {
    const { app, supabase } = makeApp();
    const response = await request(app)
      .post('/settings/ocr')
      .send({
        mode: 'internal',
        webhook_url: 'https://ocr.test/new',
        webhook_key: '',
        mistral_api_key: '',
        mistral_prompt: 'New prompt',
        mistral_output_schema: '{}'
      });

    expect(response.status).toBe(302);
    expect(response.headers.location).toBe('/settings');
    expect(supabase.state.row.value).toMatchObject({
      mode: 'internal',
      webhook_url: 'https://ocr.test/new',
      webhook_key: 'old-webhook-key',
      mistral_api_key: 'old-mistral-key',
      mistral_prompt: 'New prompt',
      mistral_output_schema: '{}'
    });
  });

  it('stores per-factory prompt and schema settings', async () => {
    const { app, supabase } = makeApp();
    const response = await request(app)
      .post('/settings/ocr')
      .send({
        mode: 'internal',
        webhook_url: 'https://ocr.test/webhook',
        mistral_prompt: 'Default prompt',
        mistral_output_schema: '{}',
        factory_settings: {
          f1: {
            factory_id: 'f1',
            factory_name: 'PT PABRIK A',
            prompt: 'Prompt pabrik A',
            output_schema: '{"type":"x"}'
          }
        }
      });

    expect(response.status).toBe(302);
    expect(supabase.state.row.value.factory_settings.f1).toMatchObject({
      factory_id: 'f1',
      factory_name: 'PT PABRIK A',
      prompt: 'Prompt pabrik A',
      output_schema: '{"type":"x"}'
    });
  });

  it('removes a factory setting when the remove flag is posted', async () => {
    const current = {
      factory_settings: {
        f1: { factory_id: 'f1', factory_name: 'PT PABRIK A', prompt: 'p', output_schema: '{}' }
      }
    };
    const { app, supabase } = makeApp(makeSupabase({ ...current }));
    const response = await request(app)
      .post('/settings/ocr')
      .send({
        mode: 'webhook',
        webhook_url: 'https://ocr.test/webhook',
        factory_settings: {
          f1: {
            factory_id: 'f1',
            factory_name: 'PT PABRIK A',
            remove: '1'
          }
        }
      });

    expect(response.status).toBe(302);
    expect(supabase.state.row.value.factory_settings.f1).toBeUndefined();
    expect(supabase.state.row.value.factory_settings).toEqual({});
  });
});
