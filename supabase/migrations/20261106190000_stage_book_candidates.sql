-- Package 23: private staging for candidate book metadata. No public publication.
create table if not exists kovunela_catalog.review_candidates (
  item_id uuid primary key references kovunela.items(id) on delete cascade,
  normalized_isbn text not null,
  base_facts jsonb not null,
  source_item_updated_at timestamptz not null,
  state text not null default 'pending_review'
    check (state in ('pending_review', 'approved', 'rejected')),
  extracted_at timestamptz not null default now()
);
alter table kovunela_catalog.review_candidates enable row level security;
revoke all on kovunela_catalog.review_candidates from public, anon, authenticated;

create or replace function kovunela_catalog.process_contribution_batch(p_limit integer default 50)
returns integer language plpgsql security definer set search_path = ''
as $function$
declare
  v_row record;
  v_isbn text;
  v_kind text;
  v_facts jsonb;
  v_processed integer := 0;
begin
  if p_limit is null or p_limit < 1 or p_limit > 200 then
    raise exception 'Invalid batch size' using errcode = '22023';
  end if;
  for v_row in
    select q.item_id, q.confirmed_item_updated_at,
           i.updated_at, i.deleted_at, i.title, i.attributes,
           i.template_version_id
    from kovunela_catalog.contribution_queue q
    left join kovunela.items i on i.id = q.item_id
    where q.state = 'pending'
    order by q.queued_at, q.item_id
    for update of q skip locked
    limit p_limit
  loop
    v_processed := v_processed + 1;
    if v_row.updated_at is null or v_row.deleted_at is not null
       or v_row.confirmed_item_updated_at is distinct from v_row.updated_at
       or nullif(btrim(v_row.title), '') is null
    then
      delete from kovunela_catalog.review_candidates where item_id=v_row.item_id;
      update kovunela_catalog.contribution_queue
        set state='skipped',last_error='item_missing_or_modified',
            processed_at=now() where item_id=v_row.item_id;
      continue;
    end if;
    select st.code into v_kind
    from kovunela.template_versions tv
    join kovunela.object_templates ot on ot.id=tv.template_id
    join kovunela.standard_templates st on st.id=ot.source_standard_id
    where tv.id=v_row.template_version_id limit 1;
    v_isbn := upper(regexp_replace(
      coalesce(v_row.attributes->>'isbn',''), '[ -]', '', 'g'));
    if v_kind is distinct from 'book'
       or not kovunela_catalog.valid_identifier(
         case when length(v_isbn)=10 then 'isbn10' else 'isbn13' end,v_isbn)
       or length(v_row.title) > 200
    then
      delete from kovunela_catalog.review_candidates where item_id=v_row.item_id;
      update kovunela_catalog.contribution_queue
        set state='skipped',last_error='not_eligible_for_catalog',
            processed_at=now() where item_id=v_row.item_id;
      continue;
    end if;
    v_facts := jsonb_build_object('title',btrim(v_row.title));
    if jsonb_typeof(v_row.attributes->'author')='string'
       and length(v_row.attributes->>'author') between 1 and 120 then
      v_facts := v_facts || jsonb_build_object('author',v_row.attributes->>'author');
    end if;
    if jsonb_typeof(v_row.attributes->'publisher')='string'
       and length(v_row.attributes->>'publisher') between 1 and 120 then
      v_facts := v_facts || jsonb_build_object('publisher',v_row.attributes->>'publisher');
    end if;
    if jsonb_typeof(v_row.attributes->'language')='string'
       and (v_row.attributes->>'language') ~ '^[a-z]{2}(-[A-Za-z0-9]{2,8})?$' then
      v_facts := v_facts || jsonb_build_object('language',v_row.attributes->>'language');
    end if;
    if jsonb_typeof(v_row.attributes->'publication_year')='number'
       and (v_row.attributes->>'publication_year') ~ '^[0-9]{4}$'
       and (v_row.attributes->>'publication_year')::int between 1450 and 2200 then
      v_facts := v_facts || jsonb_build_object('publication_year',
        v_row.attributes->'publication_year');
    end if;
    insert into kovunela_catalog.review_candidates
      (item_id,normalized_isbn,base_facts,source_item_updated_at,state,extracted_at)
    values (v_row.item_id,v_isbn,v_facts,v_row.updated_at,'pending_review',now())
    on conflict (item_id) do update
      set normalized_isbn=excluded.normalized_isbn,
          base_facts=excluded.base_facts,
          source_item_updated_at=excluded.source_item_updated_at,
          state='pending_review',extracted_at=now();
    update kovunela_catalog.contribution_queue
      set state='review',last_error=null,processed_at=now()
    where item_id=v_row.item_id;
  end loop;
  return v_processed;
end;
$function$;
revoke all on function kovunela_catalog.process_contribution_batch(integer)
  from public, anon, authenticated;
