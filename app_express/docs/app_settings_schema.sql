create table if not exists inv.app_settings (
  key text primary key,
  value jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create or replace function inv.set_app_settings_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists app_settings_updated_at on inv.app_settings;
create trigger app_settings_updated_at
before update on inv.app_settings
for each row
execute function inv.set_app_settings_updated_at();
