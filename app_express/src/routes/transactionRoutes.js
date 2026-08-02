const express = require('express');
const { asyncHandler } = require('../middleware/asyncHandler');
const { todayInput } = require('../services/request');

const router = express.Router();

router.get('/', asyncHandler(async (req, res) => {
  const start = req.query.start || todayInput();
  const end = req.query.end || todayInput();
  const factoryId = req.query.factory_id || null;

  // Ambil payment relations dengan vehicle plate numbers
  const paymentRelations = await req.supabase
    .from('payment_relations')
    .select('id, name, contact, address, payment_relation_vehicles(vehicle_id, vehicles(plate_number)), payment_relation_accounts(bank_name, account_number, account_name)')
    .order('name');

  const rels = paymentRelations.data || [];

  // Kumpulkan semua plate numbers
  const plateMap = {}; // plate -> relation
  rels.forEach(rel => {
    (rel.payment_relation_vehicles || []).forEach(pv => {
      const plate = pv.vehicles?.plate_number;
      if (plate) {
        if (!plateMap[plate]) plateMap[plate] = [];
        plateMap[plate].push(rel);
      }
    });
  });

  const plates = Object.keys(plateMap);
  let data = [];

  if (plates.length > 0) {
    // Ambil bons berdasarkan plate numbers + date filter
    let query = req.supabase
      .from('bons')
      .select('*, bon_deductions(*), nota_items(notas(*, payments(*)))')
      .in('plate_number', plates);

    if (start) query = query.gte('bon_date', start);
    if (end) query = query.lte('bon_date', `${end}T23:59:59`);
    if (factoryId) query = query.eq('factory_id', factoryId);

    const bonsResult = await query.order('created_at', { ascending: true });
    const allBons = bonsResult.data || [];

    // Group bons by relation
    const relBons = {};
    allBons.forEach(bon => {
      const relevantRels = plateMap[bon.plate_number] || [];
      relevantRels.forEach(rel => {
        if (!relBons[rel.id]) relBons[rel.id] = { relation: rel, bons: [] };
        relBons[rel.id].bons.push(bon);
      });
    });

    // Struktur data per nota & payment
    data = Object.values(relBons).map(({ relation, bons }) => {
      const notaGroups = {};
      bons.forEach(bon => {
        const ni = bon.nota_items?.[0];
        const notaId = ni?.notas?.id || '__no_nota__';
        if (!notaGroups[notaId]) {
          notaGroups[notaId] = {
            nota: ni?.notas || null,
            bons: []
          };
        }
        notaGroups[notaId].bons.push(bon);
      });

      const notas = Object.values(notaGroups).map(ng => {
        const totalKg = ng.bons.reduce((s, b) => s + Number(b.netto_2 || 0), 0);
        const totalRp = ng.bons.reduce((s, b) => s + Number(b.total || 0), 0);
        const payments = ng.nota?.payments || [];
        const totalPaid = payments.reduce((s, p) => s + Number(p.amount_paid || 0), 0);
        return {
          nota: ng.nota,
          bons: ng.bons,
          total_bons: ng.bons.length,
          total_kg: totalKg,
          total_rp: totalRp,
          payments,
          total_paid: totalPaid
        };
      });

      return {
        relation,
        notas,
        total_bons: bons.length,
        total_kg: bons.reduce((s, b) => s + Number(b.netto_2 || 0), 0),
        total_rp: bons.reduce((s, b) => s + Number(b.total || 0), 0)
      };
    });
  }

  res.render('transactions/index', {
    title: 'Transaksi Relasi',
    data,
    filters: { start, end, factory_id: factoryId }
  });
}));

module.exports = router;
