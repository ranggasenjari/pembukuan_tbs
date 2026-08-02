-- Jalankan sebelum membuka modul Relasi / Agen.
-- Semua tabel dibuat eksplisit di schema inv.

create schema if not exists inv;

create table if not exists inv.relation_agents (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  address text,
  contact text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists inv.relation_agent_accounts (
  id uuid primary key default gen_random_uuid(),
  relation_agent_id uuid not null references inv.relation_agents(id) on delete cascade,
  account_name text,
  account_number text,
  created_at timestamptz not null default now()
);

create table if not exists inv.relation_agent_drivers (
  id uuid primary key default gen_random_uuid(),
  relation_agent_id uuid not null references inv.relation_agents(id) on delete cascade,
  driver_name text,
  plate_number text,
  created_at timestamptz not null default now()
);

-- Angkutan menggantikan penggunaan langsung relation_agent_drivers.
-- Data lama tetap dibiarkan agar histori dan rollback aman.
create table if not exists inv.relation_agent_transports (
  id uuid primary key default gen_random_uuid(),
  relation_agent_id uuid not null references inv.relation_agents(id) on delete cascade,
  driver_name text not null,
  plate_number text not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists inv.factories (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  address text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists inv.factory_spsi_types (
  id uuid primary key default gen_random_uuid(),
  factory_id uuid not null references inv.factories(id) on delete cascade,
  name text not null,
  calculation_mode text not null check (calculation_mode in ('PER_KG', 'FIX')),
  amount numeric not null check (amount >= 0),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table inv.bons
  add column if not exists relation_agent_id uuid references inv.relation_agents(id) on delete set null,
  add column if not exists transport_id uuid references inv.relation_agent_transports(id) on delete set null,
  add column if not exists factory_id uuid references inv.factories(id) on delete set null,
  add column if not exists factory_spsi_type_id uuid references inv.factory_spsi_types(id) on delete set null,
  add column if not exists spsi_type_name text,
  add column if not exists spsi_calculation_mode text check (spsi_calculation_mode in ('PER_KG', 'FIX')),
  add column if not exists spsi_rate numeric,
  add column if not exists spsi_amount numeric;

alter table inv.notas
  add column if not exists relation_agent_id uuid references inv.relation_agents(id) on delete set null;

alter table inv.margins
  add column if not exists factory_id uuid references inv.factories(id) on delete set null;

-- Snapshot nilai SPSI untuk Bon lama; aplikasi tetap memakai fallback rumus lama
-- apabila migrasi ini belum pernah dijalankan pada data historis.
update inv.bons
set spsi_amount = coalesce(biaya_bongkar, 0) * coalesce(netto_1, 0),
    spsi_calculation_mode = coalesce(spsi_calculation_mode, 'PER_KG'),
    spsi_rate = coalesce(spsi_rate, biaya_bongkar)
where spsi_amount is null;

insert into inv.relation_agent_transports (relation_agent_id, driver_name, plate_number)
select relation_agent_id, coalesce(driver_name, ''), coalesce(plate_number, '')
from inv.relation_agent_drivers legacy
where coalesce(trim(driver_name), '') <> ''
  and coalesce(trim(plate_number), '') <> ''
  and not exists (
    select 1
    from inv.relation_agent_transports transport
    where transport.relation_agent_id = legacy.relation_agent_id
      and upper(transport.plate_number) = upper(legacy.plate_number)
  );

create index if not exists relation_agents_name_idx on inv.relation_agents (name);
create index if not exists relation_agent_accounts_relation_idx on inv.relation_agent_accounts (relation_agent_id);
create index if not exists relation_agent_drivers_relation_idx on inv.relation_agent_drivers (relation_agent_id);
create index if not exists relation_agent_transports_relation_idx on inv.relation_agent_transports (relation_agent_id);
create index if not exists relation_agent_transports_plate_idx on inv.relation_agent_transports (plate_number);
create index if not exists factory_spsi_types_factory_idx on inv.factory_spsi_types (factory_id);
create index if not exists bons_relation_agent_idx on inv.bons (relation_agent_id);
create index if not exists bons_transport_idx on inv.bons (transport_id);
create index if not exists bons_factory_idx on inv.bons (factory_id);
create index if not exists notas_relation_agent_idx on inv.notas (relation_agent_id);
create index if not exists margins_factory_idx on inv.margins (factory_id);
