const { applyManagedBonUpdate } = require('../src/services/managedBonUpdate');

function makeSupabase(status) {
  return {
    from() {
      return {
        select() { return this; },
        eq() { return this; },
        single: async () => ({ data: { id: 'bon-1', status }, error: null })
      };
    }
  };
}

describe('applyManagedBonUpdate', () => {
  it('rejects edits for a LUNAS bon before applying any update', async () => {
    await expect(applyManagedBonUpdate(makeSupabase('LUNAS'), 'bon-1', { price: 100 })).rejects.toThrow('sudah lunas');
  });
});
