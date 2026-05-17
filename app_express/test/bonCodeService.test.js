const { normalizeCodes, resolveBonIdsByTicketNumbers } = require('../src/services/bonCodeService');

function fakeSupabase(rowsByCode) {
  return {
    from() {
      return {
        select() {
          return this;
        },
        eq(column, value) {
          return Promise.resolve({ data: rowsByCode[value] || [], error: null });
        }
      };
    }
  };
}

describe('bonCodeService', () => {
  it('normalizes and de-duplicates bon codes', () => {
    expect(normalizeCodes([' BON-1 ', 'BON-1', '', 'BON-2'])).toEqual(['BON-1', 'BON-2']);
  });

  it('resolves ticket_number values into bon ids', async () => {
    const result = await resolveBonIdsByTicketNumbers(fakeSupabase({
      'BON-1': [{ id: 'bon-1', ticket_number: 'BON-1' }],
      'BON-2': [{ id: 'bon-2', ticket_number: 'BON-2' }]
    }), ['BON-1', 'BON-2']);

    expect(result.bonIds).toEqual(['bon-1', 'bon-2']);
  });

  it('returns 404 for missing ticket_number', async () => {
    await expect(resolveBonIdsByTicketNumbers(fakeSupabase({}), ['BON-X']))
      .rejects.toMatchObject({ status: 404, code: 'BON_CODE_NOT_FOUND' });
  });

  it('returns 409 for duplicate ticket_number', async () => {
    await expect(resolveBonIdsByTicketNumbers(fakeSupabase({
      'BON-1': [
        { id: 'bon-1', ticket_number: 'BON-1' },
        { id: 'bon-2', ticket_number: 'BON-1' }
      ]
    }), ['BON-1'])).rejects.toMatchObject({ status: 409, code: 'BON_CODE_DUPLICATE' });
  });
});
