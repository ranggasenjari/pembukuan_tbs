const { assertNoError } = require('../repositories/base');
const { PAYMENT_STATUS } = require('./calculations');

async function normalizeLegacyNotaStatuses(supabase, options = {}) {
  const dryRun = options.dryRun !== false;
  const legacyNotas = assertNoError(
    await supabase
      .from('notas')
      .select('id,status')
      .eq('status', PAYMENT_STATUS.BELUM_DIBAYAR)
  );

  const summary = {
    dryRun,
    scanned: legacyNotas.length,
    candidateNotas: 0,
    candidateBons: 0,
    normalizedNotas: 0,
    normalizedBons: 0,
    skippedNoItems: 0,
    skippedWithPayments: 0
  };

  for (const nota of legacyNotas) {
    const items = assertNoError(
      await supabase.from('nota_items').select('bon_id').eq('invoice_id', nota.id)
    );
    const bonIds = [...new Set(items.map((item) => item.bon_id).filter(Boolean))];
    if (bonIds.length === 0) {
      summary.skippedNoItems += 1;
      continue;
    }

    const payments = assertNoError(
      await supabase.from('payments').select('id').eq('invoice_id', nota.id)
    );
    if (payments.length > 0) {
      summary.skippedWithPayments += 1;
      continue;
    }

    const bons = assertNoError(
      await supabase.from('bons').select('id,status').in('id', bonIds)
    );
    const updatableBonIds = bons
      .filter((bon) => bon.status !== PAYMENT_STATUS.LUNAS)
      .map((bon) => bon.id);

    summary.candidateNotas += 1;
    summary.candidateBons += updatableBonIds.length;

    if (!dryRun) {
      assertNoError(
        await supabase
          .from('notas')
          .update({ status: PAYMENT_STATUS.TERTAGIH })
          .eq('id', nota.id)
      );

      if (updatableBonIds.length > 0) {
        assertNoError(
          await supabase
            .from('bons')
            .update({ status: PAYMENT_STATUS.TERTAGIH })
          .in('id', updatableBonIds)
        );
      }

      summary.normalizedNotas += 1;
      summary.normalizedBons += updatableBonIds.length;
    }
  }

  return summary;
}

module.exports = { normalizeLegacyNotaStatuses };
