-- Paket 23: Explicit confirmation is required before an item may enter the
-- private catalog contribution queue. No public catalog facts are published here.
-- Existing auto-queue trigger on every item insert/update is deliberately removed.
drop trigger if exists enqueue_catalog_contribution on kovunela.items;

alter table kovunela_catalog.contribution_queue
  add column if not exists confirmed_item_updated_at timestamptz,
  add column if not exists confirmed_at timestamptz;

create or replace function public.kv_confirm_item_catalog_contribution(p_item_id uuid)
returns boolean
language plpgsql
security definer
set search_path = ''
as $function$
declare
  v_item record;
  v_user uuid := auth.uid();
begin
  if v_user is null then
    raise exception 'Authentication required' using errcode = '28000';
  end if;
  -- The creator explicitly confirms their own completed item. A household
  -- member must not silently publish another member's contribution.
  select i.id, i.workspace_id, i.updated_at, i.title
    into v_item
    from kovunela.items as i
   where i.id = p_item_id
     and i.created_by = v_user
     and i.deleted_at is null
   for update;

  if not found then
    raise exception 'Item unavailable for confirmation' using errcode = '42501';
  end if;

  if nullif(btrim(v_item.title), '') is null then
    raise exception 'Item title is required' using errcode = '22023';
  end if;

  insert into kovunela_catalog.contribution_queue
      (item_id, workspace_id, state, attempt_count, last_error, queued_at,
       processed_at, confirmed_at, confirmed_item_updated_at)
  values
      (v_item.id, v_item.workspace_id, 'pending', 0, null, now(),
       null, now(), v_item.updated_at)
  on conflict (item_id) do update
     set workspace_id = excluded.workspace_id,
         state = 'pending',
         attempt_count = 0,
         last_error = null,
         queued_at = now(),
         processed_at = null,
         confirmed_at = excluded.confirmed_at,
         confirmed_item_updated_at = excluded.confirmed_item_updated_at;

  return true;
end;
$function$;

revoke all on function public.kv_confirm_item_catalog_contribution(uuid) from public, anon;
grant execute on function public.kv_confirm_item_catalog_contribution(uuid) to authenticated;

-- The eventual privileged queue processor MUST verify that the private
-- item's updated_at still matches confirmed_item_updated_at, check its
-- field-level provenance/licensing, redact private attributes, deduplicate,
-- and explicitly approve public facts before publishing.