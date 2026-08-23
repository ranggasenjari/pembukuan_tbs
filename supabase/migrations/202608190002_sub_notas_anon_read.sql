-- Izinkan dashboard (anon key) membaca sub nota, konsisten dengan bons/notas/payments.
-- EJS/API memakai user authenticated / system — sudah ter-cover policy pertama.
create policy "Anonymous users can read sub_notas"
  on inv.sub_notas
  for select
  to anon
  using (true);