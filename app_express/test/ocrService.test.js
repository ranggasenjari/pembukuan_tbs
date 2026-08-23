const {
  MISTRAL_OCR_URL,
  normalizeAnnotationFormat,
  normalizeOcrData,
  processInternalOcr,
  processWebhookOcr
} = require('../src/services/ocrService');

function makeFile() {
  return {
    buffer: Buffer.from('image'),
    mimetype: 'image/jpeg',
    originalname: 'bon.jpg'
  };
}

function makeStorageClient() {
  const upload = vi.fn(async () => ({ error: null }));
  const getPublicUrl = vi.fn(() => ({ data: { publicUrl: 'https://storage.test/bons/bon.jpg' } }));
  return {
    upload,
    getPublicUrl,
    client: {
      storage: {
        from: vi.fn(() => ({ upload, getPublicUrl }))
      }
    }
  };
}

describe('ocrService', () => {
  it('sends webhook OCR multipart with configured API key', async () => {
    const fetchMock = vi.fn(async () => ({
      ok: true,
      json: async () => ({ ticket_number: 'BON-1', path: 'bons/bon.jpg' })
    }));

    const result = await processWebhookOcr(makeFile(), {
      webhook_url: 'https://ocr.test/webhook',
      webhook_key: 'secret'
    }, { fetch: fetchMock });

    expect(fetchMock).toHaveBeenCalledWith('https://ocr.test/webhook', expect.objectContaining({
      method: 'POST',
      headers: { 'x-api-key': 'secret' }
    }));
    expect(result.data.ticket_number).toBe('BON-1');
    expect(result.image_path).toBe('bons/bon.jpg');
  });

  it('sends internal OCR to Mistral, parses document_annotation, and uploads the image', async () => {
    const fetchMock = vi.fn(async () => ({
      ok: true,
      json: async () => ({
        document_annotation: JSON.stringify({
          ticket_number: 'TBS-1',
          bon_date: '2026-08-03',
          plate_number: 'BK 1234 AB',
          driver_name: 'Budi',
          relation_name: 'Relasi',
          factory_name: 'PT Test',
          fruit_origin: 'Langkat',
          netto_1: '1,500',
          netto_2: '1400'
        })
      })
    }));
    const storage = makeStorageClient();

    const result = await processInternalOcr(makeFile(), {
      mistral_api_key: 'mistral-key',
      mistral_prompt: 'Extract data',
      mistral_output_schema: JSON.stringify({ type: 'json_schema', json_schema: { name: 'x', schema: {} } })
    }, { fetch: fetchMock, storageClient: storage.client });

    expect(fetchMock).toHaveBeenCalledWith(MISTRAL_OCR_URL, expect.objectContaining({
      method: 'POST',
      headers: expect.objectContaining({ Authorization: 'Bearer mistral-key' })
    }));
    const body = JSON.parse(fetchMock.mock.calls[0][1].body);
    expect(body.document.image_url.url).toMatch(/^data:image\/jpeg;base64,/);
    expect(result.data.plate_number).toBe('BK1234AB');
    expect(result.data.netto_1).toBe(1500);
    expect(result.image_path).toMatch(/^bons\//);
    expect(result.image_url).toBe('https://storage.test/bons/bon.jpg');
  });

  it('reports invalid internal OCR schema clearly', async () => {
    await expect(processInternalOcr(makeFile(), {
      mistral_api_key: 'mistral-key',
      mistral_prompt: 'Extract data',
      mistral_output_schema: '{bad'
    }, { fetch: vi.fn(), storageClient: makeStorageClient().client }))
      .rejects.toThrow('Output JSON schema harus berupa JSON valid.');
  });

  it('normalizes document_annotation strings for form fields', () => {
    expect(normalizeOcrData({
      document_annotation: JSON.stringify({ plate_number: 'BK 1 XY', netto_1: '2.000', netto_2: '1900' })
    })).toEqual(expect.objectContaining({
      plate_number: 'BK1XY',
      netto_1: 2000,
      netto_2: 1900
    }));
  });

  it('uses per-factory prompt & schema for internal OCR and overrides factory_name', async () => {
    const fetchMock = vi.fn(async () => ({
      ok: true,
      json: async () => ({
        document_annotation: JSON.stringify({
          ticket_number: 'TBS-F-1',
          bon_date: '2026-08-04',
          plate_number: 'BK 90 CD',
          netto_1: '500',
          netto_2: '480'
        })
      })
    }));
    const storage = makeStorageClient();

    const result = await processInternalOcr(
      makeFile(),
      {
        mistral_api_key: 'mistral-key',
        mistral_prompt: 'Default prompt',
        mistral_output_schema: JSON.stringify({ type: 'json_schema', json_schema: { name: 'x', schema: {} } })
      },
      { fetch: fetchMock, storageClient: storage.client },
      {
        factory_id: 'factory-1',
        factory_name: 'PT PABRIK A',
        prompt: 'Factory custom prompt',
        output_schema: JSON.stringify({ type: 'json_schema', json_schema: { name: 'f', schema: {} } })
      },
      'PT PABRIK A'
    );

    const body = JSON.parse(fetchMock.mock.calls[0][1].body);
    expect(body.document_annotation_prompt).toBe('Factory custom prompt');
    expect(body.document_annotation_format.json_schema.name).toBe('f');
    expect(result.data.factory_name).toBe('PT PABRIK A');
  });

  it('falls back to default prompt/schema when factory setting is empty', async () => {
    const fetchMock = vi.fn(async () => ({
      ok: true,
      json: async () => ({ document_annotation: '{}' })
    }));
    const storage = makeStorageClient();

    await processInternalOcr(
      makeFile(),
      {
        mistral_api_key: 'mistral-key',
        mistral_prompt: 'Default prompt',
        mistral_output_schema: JSON.stringify({ type: 'json_schema', json_schema: { name: 'x', schema: {} } })
      },
      { fetch: fetchMock, storageClient: storage.client },
      { factory_id: 'factory-1', prompt: '', output_schema: '' },
      'PABRIK B'
    );

    const body = JSON.parse(fetchMock.mock.calls[0][1].body);
    expect(body.document_annotation_prompt).toBe('Default prompt');
    expect(body.document_annotation_format.json_schema.name).toBe('x');
  });

  it('resolves factory settings by factory_id from options', async () => {
    const { resolveFactoryOcrSettings, resolveFactoryName } = require('../src/services/ocrService');
    const settings = {
      factory_settings: {
        'factory-1': { factory_id: 'factory-1', factory_name: 'PT A', prompt: 'p', output_schema: 's' }
      }
    };
    expect(resolveFactoryOcrSettings(settings, 'factory-1').prompt).toBe('p');
    expect(resolveFactoryOcrSettings(settings, 'factory-9x')).toBeNull();
    expect(resolveFactoryName([{ id: 'factory-1', name: 'PT A' }], 'factory-1', '')).toBe('PT A');
    expect(resolveFactoryName([], 'factory-1', 'Nama Fallback')).toBe('Nama Fallback');
  });

  it('wraps a bare JSON schema into the json_schema envelope required by Mistral', () => {
    const bare = { type: 'object', additionalProperties: false, properties: { plate_number: { type: ['string', 'null'] } }, required: ['plate_number'] };
    const wrapped = normalizeAnnotationFormat(JSON.stringify(bare));
    expect(wrapped.type).toBe('json_schema');
    expect(wrapped.json_schema.schema).toEqual(bare);
    expect(wrapped.json_schema.name).toBe('slip_timbangan');
    expect(wrapped.json_schema.strict).toBe(true);
  });

  it('keeps an already-wrapped json_schema as-is', () => {
    const full = { type: 'json_schema', json_schema: { name: 'my_slip', strict: false, schema: { type: 'object', properties: {} } } };
    expect(normalizeAnnotationFormat(JSON.stringify(full))).toEqual(full);
  });

  it('fixes the internal OCR request using a bare factory schema', async () => {
    const fetchMock = vi.fn(async () => ({
      ok: true,
      json: async () => ({ document_annotation: '{}' })
    }));
    const storage = makeStorageClient();
    const bare = { type: 'object', additionalProperties: false, properties: { plate_number: { type: ['string', 'null'] } }, required: ['plate_number'] };

    await processInternalOcr(
      makeFile(),
      {
        mistral_api_key: 'mistral-key',
        mistral_prompt: 'Default prompt',
        mistral_output_schema: JSON.stringify({ type: 'json_schema', json_schema: { name: 'x', schema: {} } })
      },
      { fetch: fetchMock, storageClient: storage.client },
      { factory_id: 'factory-1', prompt: 'Factory prompt', output_schema: JSON.stringify(bare) },
      'PABRIK TEST'
    );

    const body = JSON.parse(fetchMock.mock.calls[0][1].body);
    expect(body.document_annotation_format.type).toBe('json_schema');
    expect(body.document_annotation_format.json_schema.schema).toEqual(bare);
  });
});
