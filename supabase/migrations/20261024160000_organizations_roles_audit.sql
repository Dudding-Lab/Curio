-- Curio – Organisationen, Verbände, feingranulare Rollen und Audit-Log
-- Migration für Multimandantenfähigkeit und erweiterbare Hierarchie
-- Additive Änderungen; bestehende Tabellen bleiben kompatibel

-- =============================================================================
-- ASSOCIATIONS (Verbände – oberste Ebene, optional)
-- =============================================================================
create table public.associations (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  description text,
  created_by uuid not null references auth.users(id) on delete cascade,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index associations_created_by_idx on public.associations(created_by);

-- =============================================================================
-- ORGANIZATIONS (Bibliotheken / Unternehmen)
-- =============================================================================
create table public.organizations (
  id uuid primary key default gen_random_uuid(),
  association_id uuid references public.associations(id) on delete set null,
  name text not null,
  description text,
  created_by uuid not null references auth.users(id) on delete cascade,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index organizations_association_id_idx on public.organizations(association_id);
create index organizations_created_by_idx on public.organizations(created_by);

-- =============================================================================
-- HOUSEHOLDS erweitern (optional organization_id)
-- =============================================================================
alter table public.households
  add column organization_id uuid references public.organizations(id) on delete set null;

create index households_organization_id_idx on public.households(organization_id);

-- =============================================================================
-- ROLES (feingranulare, anpassbare Rollen)
-- =============================================================================
create table public.roles (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid references public.organizations(id) on delete cascade,
  household_id uuid references public.households(id) on delete cascade,
  name text not null,
  description text,
  permissions jsonb not null default '{}'::jsonb,
  -- Beispiel permissions: {"items": ["create","read","update"], "locations": ["read"], "members": ["invite"]}
  is_system boolean not null default false,
  created_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint roles_scope_check check (
    (organization_id is not null and household_id is null) or
    (organization_id is null and household_id is not null) or
    (organization_id is null and household_id is null) -- system-wide optional
  )
);

create index roles_organization_id_idx on public.roles(organization_id);
create index roles_household_id_idx on public.roles(household_id);

-- =============================================================================
-- MEMBERSHIPS erweitern / neue Mitgliedschaftstabellen
-- =============================================================================
-- Association members
create table public.association_members (
  association_id uuid not null references public.associations(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  role_id uuid references public.roles(id) on delete set null,
  joined_at timestamptz not null default now(),
  primary key (association_id, user_id)
);

create index association_members_user_id_idx on public.association_members(user_id);

-- Organization members
create table public.organization_members (
  organization_id uuid not null references public.organizations(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  role_id uuid references public.roles(id) on delete set null,
  joined_at timestamptz not null default now(),
  primary key (organization_id, user_id)
);

create index organization_members_user_id_idx on public.organization_members(user_id);

-- Household members: role_id hinzufügen (bestehende role-Spalte bleibt vorerst für Kompatibilität)
alter table public.household_members
  add column role_id uuid references public.roles(id) on delete set null;

-- =============================================================================
-- AUDIT LOGS
-- =============================================================================
create table public.audit_logs (
  id uuid primary key default gen_random_uuid(),
  association_id uuid references public.associations(id) on delete set null,
  organization_id uuid references public.organizations(id) on delete set null,
  household_id uuid references public.households(id) on delete set null,
  user_id uuid references auth.users(id) on delete set null,
  action text not null, -- insert, update, delete, invite, etc.
  entity_type text not null, -- item, location, household, role, etc.
  entity_id uuid,
  old_data jsonb,
  new_data jsonb,
  created_at timestamptz not null default now()
);

create index audit_logs_household_id_idx on public.audit_logs(household_id);
create index audit_logs_organization_id_idx on public.audit_logs(organization_id);
create index audit_logs_user_id_idx on public.audit_logs(user_id);
create index audit_logs_created_at_idx on public.audit_logs(created_at);

-- =============================================================================
-- ROW LEVEL SECURITY
-- =============================================================================
alter table public.associations enable row level security;
alter table public.organizations enable row level security;
alter table public.roles enable row level security;
alter table public.association_members enable row level security;
alter table public.organization_members enable row level security;
alter table public.audit_logs enable row level security;

-- Helper-Funktionen können später erweitert werden; hier grundlegende Policies

-- Associations: Mitglieder können sehen
create policy "Association members can view associations"
  on public.associations for select
  using (
    exists (
      select 1 from public.association_members am
      where am.association_id = id and am.user_id = auth.uid()
    )
  );

create policy "Authenticated users can create associations"
  on public.associations for insert
  with check (auth.uid() = created_by);

-- Organizations: Mitglieder oder über Association
create policy "Organization members can view organizations"
  on public.organizations for select
  using (
    exists (
      select 1 from public.organization_members om
      where om.organization_id = id and om.user_id = auth.uid()
    )
    or exists (
      select 1 from public.association_members am
      where am.association_id = organizations.association_id and am.user_id = auth.uid()
    )
  );

create policy "Authenticated users can create organizations"
  on public.organizations for insert
  with check (auth.uid() = created_by);

-- Roles: Sichtbar für Mitglieder der Scope-Ebene
create policy "Members can view roles in their scope"
  on public.roles for select
  using (
    (household_id is not null and public.is_household_member(household_id))
    or (organization_id is not null and exists (
      select 1 from public.organization_members om
      where om.organization_id = roles.organization_id and om.user_id = auth.uid()
    ))
  );

create policy "Admins can manage roles"
  on public.roles for all
  using (
    (household_id is not null and public.has_household_role(household_id, 'admin'))
    or (organization_id is not null and exists (
      select 1 from public.organization_members om
      where om.organization_id = roles.organization_id and om.user_id = auth.uid()
    ))
  );

-- Audit logs: Mitglieder des relevanten Scope können lesen
create policy "Members can view audit logs of their scope"
  on public.audit_logs for select
  using (
    (household_id is not null and public.is_household_member(household_id))
    or (organization_id is not null and exists (
      select 1 from public.organization_members om
      where om.organization_id = audit_logs.organization_id and om.user_id = auth.uid()
    ))
    or (association_id is not null and exists (
      select 1 from public.association_members am
      where am.association_id = audit_logs.association_id and am.user_id = auth.uid()
    ))
  );

-- Trigger für updated_at
create trigger associations_updated_at
  before update on public.associations
  for each row execute function public.set_updated_at();

create trigger organizations_updated_at
  before update on public.organizations
  for each row execute function public.set_updated_at();

create trigger roles_updated_at
  before update on public.roles
  for each row execute function public.set_updated_at();

-- Kommentare
comment on table public.associations is 'Verbände / übergeordnete Zusammenschlüsse (optional, für gewerbliche Nutzung)';
comment on table public.organizations is 'Organisationen / Bibliotheken, die mehrere Haushalte (Standorte) verbinden';
comment on table public.roles is 'Feingranulare, anpassbare Rollen mit Permissions (JSONB)';
comment on table public.audit_logs is 'Protokoll aller relevanten Änderungen für Nachvollziehbarkeit';
