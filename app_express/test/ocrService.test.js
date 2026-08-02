const {
  MISTRAL_OCR_URL,
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
});
