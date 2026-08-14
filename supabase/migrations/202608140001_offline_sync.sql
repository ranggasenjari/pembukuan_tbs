-- Offline-first synchronization primitives for schema inv.
alter table inv.bons add column if not exists sync_version bigint not null default 1;
alter table inv.notas add column if not exists sync_version bigint not null default 1;

create table if not exists inv.offline_sync_operations (
  user_id uuid not null default auth.uid(),
  device_id text not null,
  operation_id uuid not null,
  payload_hash text not null,
  result jsonb not null,
  applied_at timestamptz not null default now(),
  primary key (user_id, device_id, operation_id)
);

create unique index if not exists notas_invoice_number_unique
  on inv.notas (invoice_number);

create or replace function inv.bump_offline_sync_version()
returns trigger language plpgsql as $$
begin
  new.sync_version := old.sync_version + 1;
  new.updated_at := now();
  return new;
end;
$$;

drop trigger if exists bons_bump_offline_sync_version on inv.bons;
create trigger bons_bump_offline_sync_version
before update on inv.bons for each row execute function inv.bump_offline_sync_version();
drop trigger if exists notas_bump_offline_sync_version on inv.notas;
create trigger notas_bump_offline_sync_version
before update on inv.notas for each row execute function inv.bump_offline_sync_version();

-- One call is one database transaction. The Edge Function invokes this RPC
-- with the caller JWT, so existing RLS policies continue to decide access.
create or replace function inv.apply_offline_sync(
  p_device_id text,
  p_operation_id uuid,
  p_entity_type text,
  p_payload jsonb,
  p_attachment_url text default null
) returns jsonb
language plpgsql
security invoker
set search_path = inv, public
as $$
declare
  v_existing jsonb;
  v_hash text := md5(p_payload::text || coalesce(p_attachment_url, ''));
  v_bon jsonb;
  v_nota jsonb;
  v_id uuid;
  v_version bigint;
  v_base bigint;
  v_bon_id uuid;
  v_result jsonb;
begin
  select result into v_existing from inv.offline_sync_operations
    where user_id = auth.uid() and device_id = p_device_id and operation_id = p_operation_id;
  if v_existing is not null then return v_existing; end if;

  if p_entity_type = 'bon' then
    v_bon := p_payload->'bon';
    v_id := (v_bon->>'id')::uuid;
    v_base := nullif(p_payload->>'base_version', '')::bigint;
    if v_base is null then
      insert into inv.bons (
        id, ticket_number, bon_date, plate_number, driver_name, relation_name,
        relation_agent_id, factory_id, factory_spsi_type_id, spsi_type_name,
        spsi_calculation_mode, spsi_rate, spsi_amount, fruit_origin, notes,
        netto_1, netto_2, price, dp, biaya_bongkar, bp_colt, pph, uang_minum,
        total, image_url, status
      ) values (
        v_id, nullif(v_bon->>'ticket_number',''), (v_bon->>'bon_date')::date,
        v_bon->>'plate_number', nullif(v_bon->>'driver_name',''), nullif(v_bon->>'relation_name',''),
        nullif(v_bon->>'relation_agent_id','')::uuid, nullif(v_bon->>'factory_id','')::uuid,
        nullif(v_bon->>'factory_spsi_type_id','')::uuid, nullif(v_bon->>'spsi_type_name',''),
        coalesce(v_bon->>'spsi_calculation_mode','PER_KG'), coalesce((v_bon->>'spsi_rate')::integer, 0),
        coalesce((v_bon->>'spsi_amount')::integer, 0), nullif(v_bon->>'fruit_origin',''), nullif(v_bon->>'notes',''),
        coalesce((v_bon->>'netto_1')::integer, 0), coalesce((v_bon->>'netto_2')::integer, 0),
        coalesce((v_bon->>'price')::integer, 0), coalesce((v_bon->>'dp')::integer, 0),
        coalesce((v_bon->>'biaya_bongkar')::integer, 0), coalesce((v_bon->>'bp_colt')::integer, 0),
        coalesce((v_bon->>'pph')::integer, 0), coalesce((v_bon->>'uang_minum')::integer, 0),
        coalesce((v_bon->>'total')::integer, 0), coalesce(p_attachment_url, v_bon->>'image_url'),
        coalesce(v_bon->>'status', 'BELUM_DIBAYAR')
      ) on conflict (id) do nothing returning sync_version into v_version;
      if v_version is null and exists(select 1 from inv.bons where id = v_id) then
        v_result := jsonb_build_object('status','conflict','message','Data cloud sudah ada.');
      end if;
    else
      update inv.bons set
        ticket_number = nullif(v_bon->>'ticket_number',''), bon_date = (v_bon->>'bon_date')::date,
        plate_number = v_bon->>'plate_number', driver_name = nullif(v_bon->>'driver_name',''),
        relation_name = nullif(v_bon->>'relation_name',''), relation_agent_id = nullif(v_bon->>'relation_agent_id','')::uuid,
        factory_id = nullif(v_bon->>'factory_id','')::uuid, factory_spsi_type_id = nullif(v_bon->>'factory_spsi_type_id','')::uuid,
        spsi_type_name = nullif(v_bon->>'spsi_type_name',''), spsi_calculation_mode = coalesce(v_bon->>'spsi_calculation_mode','PER_KG'),
        spsi_rate = coalesce((v_bon->>'spsi_rate')::integer,0), spsi_amount = coalesce((v_bon->>'spsi_amount')::integer,0),
        fruit_origin = nullif(v_bon->>'fruit_origin',''), notes = nullif(v_bon->>'notes',''),
        netto_1 = coalesce((v_bon->>'netto_1')::integer,0), netto_2 = coalesce((v_bon->>'netto_2')::integer,0),
        price = coalesce((v_bon->>'price')::integer,0), dp = coalesce((v_bon->>'dp')::integer,0),
        biaya_bongkar = coalesce((v_bon->>'biaya_bongkar')::integer,0), bp_colt = coalesce((v_bon->>'bp_colt')::integer,0),
        pph = coalesce((v_bon->>'pph')::integer,0), uang_minum = coalesce((v_bon->>'uang_minum')::integer,0),
        total = coalesce((v_bon->>'total')::integer,0), image_url = coalesce(p_attachment_url, image_url)
        where id = v_id and sync_version = v_base returning sync_version into v_version;
      if v_version is null then v_result := jsonb_build_object('status','conflict'); end if;
    end if;
    if v_result is null then
      delete from inv.bon_deductions where bon_id = v_id;
      insert into inv.bon_deductions (bon_id, label, amount)
        select v_id, item->>'label', coalesce((item->>'amount')::integer, 0)
        from jsonb_array_elements(coalesce(v_bon->'bon_deductions','[]'::jsonb)) item;
      v_result := jsonb_build_object('status','ok','sync_version',v_version);
    end if;

  elsif p_entity_type = 'nota' then
    v_nota := p_payload->'nota';
    v_id := (v_nota->>'id')::uuid;
    insert into inv.notas (id, invoice_number, invoice_date, total_amount, status, relation_agent_id, recipient_name, recipient_address)
      values (v_id, v_nota->>'invoice_number', (v_nota->>'invoice_date')::date,
        coalesce((v_nota->>'total_amount')::integer,0), coalesce(v_nota->>'status','TERTAGIH'),
        nullif(v_nota->>'relation_agent_id','')::uuid, nullif(v_nota->>'recipient_name',''), nullif(v_nota->>'recipient_address',''))
      on conflict (id) do update set total_amount = excluded.total_amount, status = excluded.status,
        relation_agent_id = excluded.relation_agent_id, recipient_name = excluded.recipient_name,
        recipient_address = excluded.recipient_address returning sync_version into v_version;
    delete from inv.nota_items where invoice_id = v_id;
    for v_bon_id in select value::uuid from jsonb_array_elements_text(coalesce(v_nota->'bon_ids','[]'::jsonb)) loop
      insert into inv.nota_items (invoice_id, bon_id) values (v_id, v_bon_id);
      update inv.bons set status = 'TERTAGIH' where id = v_bon_id;
    end loop;
    v_result := jsonb_build_object('status','ok','sync_version',v_version);

  elsif p_entity_type = 'bon_delete' then
    v_id := (p_payload->>'bon_id')::uuid;
    v_base := (p_payload->>'base_version')::bigint;
    delete from inv.bons where id = v_id and sync_version = v_base and status = 'BELUM_DIBAYAR';
    if found then v_result := jsonb_build_object('status','ok');
    else v_result := jsonb_build_object('status','conflict'); end if;
  else
    raise exception 'Unknown offline entity type: %', p_entity_type;
  end if;

  insert into inv.offline_sync_operations (user_id, device_id, operation_id, payload_hash, result)
    values (auth.uid(), p_device_id, p_operation_id, v_hash, v_result);
  return v_result;
end;
$$;
