-- Tambahan data Relasi Bayar: fee, hutang, rolling, dan giringan.
-- - fee: nilai tetap (Rp) per relasi bayar.
-- - hutang: daftar entri (tanggal, Rp, catatan).
-- - rolling: daftar entri (tanggal, Rp, catatan).
-- - giringan: daftar nama (crew/giringan) bebas.

alter table inv.payment_relations
  add column if not exists fee integer;

create table if not exists inv.payment_relation_hutang (
  id uuid primary key default gen_random_uuid(),
  payment_relation_id uuid not null references inv.payment_relations(id) on delete cascade,
  tanggal date not null,
  amount integer not null default 0,
  notes text,
  created_at timestamptz not null default now()
);

create table if not exists inv.payment_relation_rolling (
  id uuid primary key default gen_random_uuid(),
  payment_relation_id uuid not null references inv.payment_relations(id) on delete cascade,
  tanggal date not null,
  amount integer not null default 0,
  notes text,
  created_at timestamptz not null default now()
);

create table if not exists inv.payment_relation_giringan (
  id uuid primary key default gen_random_uuid(),
  payment_relation_id uuid not null references inv.payment_relations(id) on delete cascade,
  name text not null,
  created_at timestamptz not null default now()
);

create index if not exists payment_relation_hutang_relation_idx on inv.payment_relation_hutang (payment_relation_id);
create index if not exists payment_relation_rolling_relation_idx on inv.payment_relation_rolling (payment_relation_id);
create index if not exists payment_relation_giringan_relation_idx on inv.payment_relation_giringan (payment_relation_id);

alter table inv.payment_relation_hutang enable row level security;
alter table inv.payment_relation_rolling enable row level security;
alter table inv.payment_relation_giringan enable row level security;

create policy "Authenticated users can manage payment_relation_hutang"
  on inv.payment_relation_hutang
  for all
  to authenticated
  using (true)
  with check (true);

create policy "Authenticated users can manage payment_relation_rolling"
  on inv.payment_relation_rolling
  for all
  to authenticated
  using (true)
  with check (true);

create policy "Authenticated users can manage payment_relation_giringan"
  on inv.payment_relation_giringan
  for all
  to authenticated
  using (true)
  with check (true);
