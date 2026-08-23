const { applyDateRange, assertNoError } = require('./base');

function normalizePlate(value) {
  return String(value || '').replace(/\s+/g, '').toUpperCase();
}

function summarize(bons) {
  return {
    totalBons: bons.length,
    unbilledBons: bons.filter((bon) => bon.status === 'BELUM_DIBAYAR').length,
    billedBons: bons.filter((bon) => bon.status === 'TERTAGIH').length,
    paidBons: bons.filter((bon) => bon.status === 'LUNAS').length,
    totalTonnage: bons.reduce((sum, bon) => sum + Number(bon.netto_2 || 0), 0) / 1000
  };
}

async function listManagedBons(supabase, filters = {}) {
  let query = supabase
    .from('bons')
    .select('*, bon_deductions(*), factories(name), relation_agents(name), nota_items(notas(*, payments(*)))');
  query = applyDateRange(query, 'bon_date', filters.start, filters.end);
  if (filters.status) query = query.eq('status', filters.status);
  if (filters.factory_id) query = query.eq('factory_id', filters.factory_id);
  if (filters.q) {
    const q = String(filters.q).trim();
    query = query.or(`ticket_number.ilike.%${q}%,driver_name.ilike.%${q}%,plate_number.ilike.%${q}%,relation_name.ilike.%${q}%`);
  }

  const bons = assertNoError(await query.order('created_at', { ascending: false }));
  const plates = [...new Set(bons.map((bon) => normalizePlate(bon.plate_number)).filter(Boolean))];
  const relationByPlate = {};

  if (plates.length) {
    const rows = assertNoError(
      await supabase
        .from('payment_relation_vehicles')
        .select('vehicles(plate_number), payment_relations(*, payment_relation_accounts(*))')
        .in('vehicles.plate_number', plates)
    );

    rows.forEach((row) => {
      const plate = normalizePlate(row.vehicles?.plate_number);
      if (plate && row.payment_relations && !relationByPlate[plate]) {
        relationByPlate[plate] = row.payment_relations;
      }
    });
  }

  // Sub nota diambil terpisah & defensif: bila tabel belum migrasi,
  // halaman Manajemen Bon tetap berjalan (sub nota kosong).
  const subNotasByBon = {};
  try {
    const ids = bons.map((bon) => bon.id);
    if (ids.length) {
      const rows = assertNoError(
        await supabase.from('sub_notas').select('*').in('bon_id', ids)
      );
      rows.forEach((row) => {
        (subNotasByBon[row.bon_id] = subNotasByBon[row.bon_id] || []).push(row);
      });
      Object.values(subNotasByBon).forEach((list) =>
        list.sort((a, b) => new Date(b.created_at) - new Date(a.created_at))
      );
    }
  } catch (error) {
    console.error('Sub nota query error (table mungkin belum migrasi):', error.message);
  }

  const items = bons.map((bon) => {
    const nota = bon.nota_items?.[0]?.notas || null;
    const payments = nota?.payments || [];
    return {
      bon,
      paymentRelation: relationByPlate[normalizePlate(bon.plate_number)] || null,
      nota,
      payments,
      subNotas: subNotasByBon[bon.id] || []
    };
  });

  return {
    items,
    summary: summarize(bons)
  };
}

module.exports = { listManagedBons, normalizePlate, summarize };
