-- KOVUNELA PHASE 1 / DEVELOPMENT ONLY / UNREVIEWED
-- NEVER RUN AGAINST PRODUCTION OR AN EXISTING LEGACY PROJECT.
-- Requires a freshly provisioned, isolated Supabase development project.
-- This focused vertical slice is a proof of authorization design, NOT the full
-- 20-table Curio v2 schema. Reconcile with complete schema before deployment.
begin;

create extension if not exists pgcrypto;

create table public.workspaces (
  id uuid primary key default gen_random_uuid(),
  kind text not null check (kind in ('personal','household')),
  name text not null check (char_length(btrim(name)) between 1 and 200),
  created_by uuid not null references auth.users(id),
  created_at timestamptz not null default now()
);
create unique index workspaces_unique_personal
  on public.workspaces (created_by) where kind = 'personal';

create table public.workspace_members (
  workspace_id uuid not null references public.workspaces(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  role text not null check (role in ('owner','admin','editor','viewer')),
  joined_at timestamptz not null default now(),
  primary key (workspace_id, user_id)
);
create index workspace_members_user_id_idx on public.workspace_members(user_id);

create table public.items (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references public.workspaces(id),
  title text not null check (char_length(btrim(title)) between 1 and 200),
  description text not null default '' check (char_length(description) <= 5000),
  created_by uuid not null references auth.users(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz,
  deleted_by uuid references auth.users(id),
  constraint deleted_audit_consistent
    check ((deleted_at is null) = (deleted_by is null))
);
create index items_workspace_active_idx
  on public.items (workspace_id, created_at desc)
  where deleted_at is null;

alter table public.workspaces enable row level security;
alter table public.workspace_members enable row level security;
alter table public.items enable row level security;

-- RLS must not recurse through workspace_members' own policy.
-- This trusted read-only check is narrow and uses a fixed search path.
create function public.kv_is_workspace_member(p_workspace_id uuid)
returns boolean
language sql stable security definer
set search_path = ''
as $$
  select auth.uid() is not null and exists (
    select 1 from public.workspace_members m
    where m.workspace_id = p_workspace_id
      and m.user_id = auth.uid()
  )
$$;

create policy workspace_read_members on public.workspaces
  for select to authenticated
  using (public.kv_is_workspace_member(id));

create policy member_read_self on public.workspace_members
  for select to authenticated
  using (user_id = (select auth.uid()));

create policy items_read_members on public.items
  for select to authenticated
  using (deleted_at is null and public.kv_is_workspace_member(workspace_id));

-- No public INSERT/UPDATE/DELETE policies. Writes are limited to audited RPC.
-- One user may create/retrieve only their own personal workspace.
create function public.kv_ensure_personal_workspace()
returns uuid
language plpgsql volatile security definer
set search_path = ''
as $$
declare
  v_user uuid := auth.uid();
  v_workspace uuid;
begin
  if v_user is null then
    raise exception 'Authentication required' using errcode = '28000';
  end if;

  insert into public.workspaces(kind, name, created_by)
  values ('personal', 'Personal', v_user)
  on conflict (created_by) where kind = 'personal'
  do nothing;

  select id into v_workspace from public.workspaces
  where created_by = v_user and kind = 'personal';

  if v_workspace is null then
    raise exception 'Workspace provisioning failed';
  end if;

  insert into public.workspace_members(workspace_id, user_id, role)
  values (v_workspace, v_user, 'owner')
  on conflict (workspace_id, user_id) do nothing;

  return v_workspace;
end;
$$;

-- First version permits creation ONLY within the caller's personal workspace.
-- Never trust creator/workspace member fields supplied by the client.
create function public.kv_create_personal_item(
  p_title text,
  p_description text default ''
)
returns uuid
language plpgsql volatile security definer
set search_path = ''
as $$
declare
  v_user uuid := auth.uid();
  v_workspace uuid;
  v_item uuid;
begin
  if v_user is null then
    raise exception 'Authentication required' using errcode = '28000';
  end if;
  if p_title is null or char_length(btrim(p_title)) not between 1 and 200 then
    raise exception 'Invalid item title' using errcode = '22023';
  end if;
  if p_description is null or char_length(p_description) > 5000 then
    raise exception 'Invalid item description' using errcode = '22023';
  end if;

  v_workspace := public.kv_ensure_personal_workspace();
  if not exists (
    select 1 from public.workspace_members m
    where m.workspace_id = v_workspace
      and m.user_id = v_user
      and m.role = 'owner'
  ) then
    raise exception 'Item creation not permitted' using errcode = '42501';
  end if;

  insert into public.items(workspace_id, title, description, created_by)
  values (v_workspace, btrim(p_title), btrim(p_description), v_user)
  returning id into v_item;
  return v_item;
end;
$$;

-- Limit RPC execution. Supabase/PostgREST should expose only vetted RPCs.
revoke all on function public.kv_is_workspace_member(uuid) from public, anon;
revoke all on function public.kv_ensure_personal_workspace() from public, anon;
revoke all on function public.kv_create_personal_item(text,text) from public, anon;
grant execute on function public.kv_is_workspace_member(uuid) to authenticated;
grant execute on function public.kv_ensure_personal_workspace() to authenticated;
grant execute on function public.kv_create_personal_item(text,text) to authenticated;

-- Explicit grants are required because Postgres default grants may differ.
revoke all on public.workspaces, public.workspace_members, public.items
  from anon, authenticated;
grant select on public.workspaces, public.workspace_members, public.items
  to authenticated;

commit;
