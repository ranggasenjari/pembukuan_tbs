require('dotenv').config();
const { createClient } = require('@supabase/supabase-js');
const supabase = createClient(process.env.SUPABASE_URL, process.env.SUPABASE_KEY, {
  db: { schema: process.env.SUPABASE_SCHEMA || 'inv' },
  auth: { persistSession: false }
});
(async () => {
  const tables = ['bons', 'payments', 'notas', 'sub_notas'];
  for (const t of tables) {
    const r = await supabase.from(t).select('*', { count: 'exact', head: true });
    console.log(t + ' => count=' + (r.count ?? 'NULL') + ' err=' + (r.error ? JSON.stringify(r.error) : '-'));
  }
})();