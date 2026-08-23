require('dotenv').config();
const { createClient } = require('@supabase/supabase-js');
const supabase = createClient(process.env.SUPABASE_URL, process.env.SUPABASE_KEY, {
  db: { schema: process.env.SUPABASE_SCHEMA || 'inv' },
  auth: { persistSession: false }
});

(async () => {
  const { data: subs, error: e1 } = await supabase.from('sub_notas').select('id, bon_id, name, price_per_kg, netto_2, amount, created_at').limit(20);
  if (e1) { console.log('SUB_SEL_ERR ' + JSON.stringify(e1)); return; }
  console.log('SUBNOTAS_COUNT=' + subs.length);
  console.log(JSON.stringify(subs, null, 0));

  const list = await supabase.from('bons').select('id, plate_number, bon_date, netto_2').order('created_at', { ascending: false }).limit(3);
  console.log('LATEST_BONS=' + JSON.stringify(list.data));

  if (subs.length > 0) {
    const bid = subs[0].bon_id;
    const { data: bon, error: e2 } = await supabase.from('bons').select('id, bon_date, plate_number').eq('id', bid).maybeSingle();
    console.log('SUBNOTA_BON=' + JSON.stringify(bon) + ' err=' + (e2 && JSON.stringify(e2)));
  }
})();