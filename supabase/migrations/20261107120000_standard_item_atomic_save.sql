-- Reuse a user's versioned standard template and save a typed object atomically.
-- This RPC is authenticated-only and never publishes to the shared catalog.
create or replace function kovunela.create_standard_personal_item(
  p_standard_code text,
  p_title text,
  p_description text,
  p_attributes jsonb
) returns uuid
language plpgsql security definer set search_path = ''
as $$
declare
  v_ws uuid;
  v_std kovunela.standard_templates%rowtype;
  v_version uuid;
  v_template uuid;
begin
  if auth.uid() is null then
    raise exception 'Authentication required' using errcode='28000';
  end if;
  if p_standard_code is null or p_standard_code !~ '^[a-z][a-z0-9_]{0,63}$' then
    raise exception 'Invalid standard code' using errcode='22023';
  end if;
  select * into v_std
  from kovunela.standard_templates
  where code = p_standard_code;
  if not found then
    raise exception 'Unknown standard template' using errcode='22023';
  end if;

  -- Serialize only within this user's standard code, avoiding duplicate
  -- personal derivatives on concurrent saves.
  perform pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended(auth.uid()::text || ':' || p_standard_code, 0)
  );
  v_ws := kovunela.ensure_personal_workspace();
  select tv.id into v_version
  from kovunela.object_templates ot
  join kovunela.template_versions tv
    on tv.template_id=ot.id and tv.workspace_id=ot.workspace_id
  where ot.workspace_id=v_ws
    and ot.source_standard_id=v_std.id
    and ot.source_version=v_std.version
    and tv.field_schema=v_std.field_schema
  order by ot.created_at, tv.version
  limit 1;

  if v_version is null then
    v_template := kovunela.derive_standard_template(v_std.id, null, '{}'::jsonb);
    select tv.id into v_version
    from kovunela.template_versions tv
    where tv.workspace_id=v_ws and tv.template_id=v_template
    order by tv.version desc limit 1;
  end if;
  if v_version is null then
    raise exception 'Template version not available' using errcode='22023';
  end if;

  return kovunela.create_typed_personal_item(
    p_title, p_description, null, v_version, p_attributes
  );
end;
$$;
revoke all on function kovunela.create_standard_personal_item(text,text,text,jsonb) from public, anon, authenticated;
create or replace function public.kv_create_standard_personal_item(
  p_standard_code text,
  p_title text,
  p_description text,
  p_attributes jsonb
) returns uuid
language sql set search_path=''
as $$
  select kovunela.create_standard_personal_item(
    p_standard_code, p_title, p_description, p_attributes
  );
$$;
revoke all on function public.kv_create_standard_personal_item(text,text,text,jsonb) from public, anon;
grant execute on function public.kv_create_standard_personal_item(text,text,text,jsonb) to authenticated;
