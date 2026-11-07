-- Package 24: private ISBN equivalence and conflict detection.
create or replace function kovunela_catalog.canonical_isbn13(p_raw text)
returns text language plpgsql immutable set search_path = ''
as $$
declare v text := upper(regexp_replace(coalesce(p_raw,''), '[ -]', '', 'g'));
 v_stem text; v_sum integer; v_check integer;
begin
 if length(v)=13 then
   if left(v,3) not in ('978','979') or
      not kovunela_catalog.valid_identifier('isbn13',v) then return null; end if;
   return v;
 end if;
 if length(v)<>10 or not kovunela_catalog.valid_identifier('isbn10',v) then return null; end if;
 v_stem := '978' || left(v,9);
 select sum(substr(v_stem,i,1)::integer *
  case when i%2=0 then 3 else 1 end)
 into v_sum from generate_series(1,12) as i;
 v_check := (10 - (v_sum % 10)) % 10;
 return v_stem || v_check::text;
end; $$;
revoke all on function kovunela_catalog.canonical_isbn13(text) from public,anon,authenticated;
create table if not exists kovunela_catalog.identifier_review_groups (
 isbn13 text primary key check(isbn13 ~ '^97[89][0-9]{10}$'),
 candidate_count integer not null check(candidate_count > 0),
 has_conflicting_facts boolean not null,
 matched_published_entity boolean not null,
 review_state text not null check(review_state in ('needs_review','conflict','already_catalogued')),
 refreshed_at timestamptz not null default now()
);
alter table kovunela_catalog.identifier_review_groups enable row level security;
revoke all on kovunela_catalog.identifier_review_groups from public,anon,authenticated;
create or replace function kovunela_catalog.refresh_identifier_review_groups()
returns integer language plpgsql security definer set search_path = ''
as $$
declare v_count integer;
begin
 with eligible as (
  select kovunela_catalog.canonical_isbn13(c.normalized_isbn) isbn13, c.base_facts
  from kovunela_catalog.review_candidates c
  join kovunela_catalog.contribution_queue q on q.item_id=c.item_id and q.state='review'
  join kovunela.items i on i.id=c.item_id and i.deleted_at is null and i.updated_at=c.source_item_updated_at
  where c.state='pending_review'
 ), summary as (
  select e.isbn13, count(*)::integer candidate_count,
   (count(distinct nullif(lower(btrim(e.base_facts->>'title')),''))>1
    or count(distinct nullif(lower(btrim(e.base_facts->>'author')),''))>1
    or count(distinct nullif(lower(btrim(e.base_facts->>'publisher')),''))>1
    or count(distinct nullif(lower(btrim(e.base_facts->>'language')),''))>1
    or count(distinct e.base_facts->>'publication_year')>1) conflict
  from eligible e where e.isbn13 is not null group by e.isbn13
 ), catalog_match as (
  select s.*,exists (
   select 1 from kovunela_catalog.identifiers ids
   join kovunela_catalog.entities en on en.id=ids.entity_id and en.status='approved'
   where (ids.identifier_type='isbn13' and ids.identifier_value=s.isbn13)
    or (ids.identifier_type='isbn10' and
      kovunela_catalog.canonical_isbn13(ids.identifier_value)=s.isbn13)
  ) matched from summary s
 )
 insert into kovunela_catalog.identifier_review_groups
  (isbn13,candidate_count,has_conflicting_facts,matched_published_entity,review_state,refreshed_at)
 select isbn13,candidate_count,conflict,matched,
  case when matched then 'already_catalogued' when conflict then 'conflict'
   else 'needs_review' end,now()
 from catalog_match
 on conflict(isbn13) do update set
  candidate_count=excluded.candidate_count,
  has_conflicting_facts=excluded.has_conflicting_facts,
  matched_published_entity=excluded.matched_published_entity,
  review_state=excluded.review_state,refreshed_at=excluded.refreshed_at;
 delete from kovunela_catalog.identifier_review_groups g
 where not exists (
  select 1 from kovunela_catalog.review_candidates c
  join kovunela_catalog.contribution_queue q on q.item_id=c.item_id and q.state='review'
  join kovunela.items i on i.id=c.item_id and i.deleted_at is null and i.updated_at=c.source_item_updated_at
  where c.state='pending_review'
   and kovunela_catalog.canonical_isbn13(c.normalized_isbn)=g.isbn13
 );
 select count(*) into v_count from kovunela_catalog.identifier_review_groups;
 return v_count;
end; $$;
revoke all on function kovunela_catalog.refresh_identifier_review_groups()
 from public,anon,authenticated;
select cron.schedule('kovunela-catalog-identifier-review','*/2 * * * *',
 $$select kovunela_catalog.refresh_identifier_review_groups();$$);
