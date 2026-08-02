-- Jalankan untuk mengaktifkan modul Relasi Bayar.
-- Modul ini independen dari Bon dan Nota.

create schema if not exists inv;

create table if not exists inv.payment_relations (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  contact text,
  address text,
  notes text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table inv.payment_relations
  add column if not exists notes text;

create table if not exists inv.payment_relation_accounts (
  id uuid primary key default gen_random_uuid(),
  payment_relation_id uuid not null references inv.payment_relations(id) on delete cascade,
  bank_name text,
  account_number text,
  account_name text,
  created_at timestamptz not null default now()
);

create table if not exists inv.payment_relation_vehicles (
  id uuid primary key default gen_random_uuid(),
  payment_relation_id uuid not null references inv.payment_relations(id) on delete cascade,
  vehicle_id uuid not null references inv.vehicles(id) on delete cascade,
  created_at timestamptz not null default now(),
  unique (payment_relation_id, vehicle_id)
);

create index if not exists payment_relations_name_idx on inv.payment_relations (name);
create index if not exists payment_relation_accounts_relation_idx on inv.payment_relation_accounts (payment_relation_id);
create index if not exists payment_relation_vehicles_relation_idx on inv.payment_relation_vehicles (payment_relation_id);
create index if not exists payment_relation_vehicles_vehicle_idx on inv.payment_relation_vehicles (vehicle_id);
