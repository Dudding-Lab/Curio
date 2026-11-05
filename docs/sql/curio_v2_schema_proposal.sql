-- Curio 2.0 — relational schema PROPOSAL, 2026-11-05
-- DESIGN REFERENCE ONLY. NOT TESTED, NOT APPLIED. DO NOT EXECUTE ON PRODUCTION.
-- Intent: clean PostgreSQL database in a separate Supabase development project.
-- No access policies are opened by this file: RLS is enabled and no client policies
-- are installed until the carefully reviewed policy/RPC migration exists.
-- The currently deployed Supabase schema and legacy migrations must be audited
-- before translating this into an executable supabase/migrations/ change.
begin;

create extension if not exists pgcrypto;

create type public.curio_workspace_kind as enum ('personal','household');
create type public.curio_workspace_role as enum ('owner','admin','editor','viewer');
create type public.curio_collection_kind as enum ('manual','smart');
create type public.curio_tracking_mode as enum ('individual','quantity');
create type public.curio_share_resource as enum ('item','collection');
create type public.curio_ai_state as enum ('queued','running','completed','failed','cancelled');

create table public.profiles (
 user_id uuid primary key references auth.users(id) on delete cascade,
 display_name text,
 locale text not null default 'en',
 created_at timestamptz not null default now(),
 updated_at timestamptz not null default now()
);

create table public.workspaces (
 id uuid primary key default gen_random_uuid(),
 kind public.curio_workspace_kind not null,
 name text not null check (length(btrim(name)) between 1 and 200),
 created_by uuid not null references auth.users(id),
 created_at timestamptz not null default now(),
 updated_at timestamptz not null default now(),
 deleted_at timestamptz,
 unique (id, kind)
);
create unique index workspaces_one_personal_per_user
 on public.workspaces(created_by) where kind='personal';

create table public.workspace_members (
 workspace_id uuid not null references public.workspaces(id) on delete cascade,
 user_id uuid not null references auth.users(id) on delete cascade,
 role public.curio_workspace_role not null,
 joined_at timestamptz not null default now(),
 primary key (workspace_id, user_id)
);
create index workspace_members_user_idx on public.workspace_members(user_id);

create table public.workspace_invites (
 id uuid primary key default gen_random_uuid(),
 workspace_id uuid not null references public.workspaces(id) on delete cascade,
 created_by uuid not null references auth.users(id),
 invited_email text,
 invite_role public.curio_workspace_role not null check (invite_role <> 'owner'),
 token_hash text not null unique,
 expires_at timestamptz not null,
 accepted_by uuid references auth.users(id),
 accepted_at timestamptz,
 revoked_at timestamptz,
 created_at timestamptz not null default now(),
 check ((accepted_at is null) = (accepted_by is null)),
 check (expires_at > created_at),
 unique (workspace_id, id)
);
create index workspace_invites_workspace_idx on public.workspace_invites(workspace_id,expires_at);

create table public.categories (
 id uuid primary key default gen_random_uuid(),
 workspace_id uuid references public.workspaces(id) on delete cascade,
 parent_id uuid references public.categories(id),
 code text not null check(length(btrim(code)) > 0),
 label text not null check(length(btrim(label)) > 0),
 created_at timestamptz not null default now(),
 unique (workspace_id,id)
);
create unique index categories_global_code_idx on public.categories(code) where workspace_id is null;
create unique index categories_workspace_code_idx on public.categories(workspace_id,code) where workspace_id is not null;
-- Parent category scope and acyclicity require a guarded function/trigger.

create table public.object_templates (
 id uuid primary key default gen_random_uuid(),
 workspace_id uuid references public.workspaces(id) on delete cascade,
 category_id uuid references public.categories(id),
 title text not null check(length(btrim(title)) > 0),
 created_by uuid references auth.users(id),
 created_at timestamptz not null default now(),
 unique (workspace_id,id)
);
create table public.template_versions (
 id uuid primary key default gen_random_uuid(),
 template_id uuid not null references public.object_templates(id) on delete cascade,
 version int not null check(version > 0),
 field_schema jsonb not null check(jsonb_typeof(field_schema) = 'object'),
 published_at timestamptz not null default now(),
 unique(template_id,version),
 unique(template_id,id)
);
-- Published versions must be immutable by role/trigger in implementation.

create table public.locations (
 id uuid primary key default gen_random_uuid(),
 workspace_id uuid not null references public.workspaces(id) on delete cascade,
 parent_id uuid,
 label text not null check(length(btrim(label)) > 0),
 kind text not null default 'place',
 created_at timestamptz not null default now(),
 unique(workspace_id,id),
 foreign key(workspace_id,parent_id) references public.locations(workspace_id,id),
 check(parent_id is distinct from id)
);
-- Prevent deeper hierarchy cycles with a privileged recursive check trigger.

create table public.items (
 id uuid primary key default gen_random_uuid(),
 workspace_id uuid not null references public.workspaces(id) on delete cascade,
 title text not null check(length(btrim(title)) > 0),
 description text,
 created_by uuid not null references auth.users(id),
 owner_user_id uuid references auth.users(id),
 category_id uuid references public.categories(id),
 template_version_id uuid references public.template_versions(id),
 location_id uuid,
 condition_label text,
 tracking_mode public.curio_tracking_mode not null default 'individual',
 quantity_amount numeric(16,3) not null default 1 check(quantity_amount > 0),
 quantity_unit text not null default 'piece' check(length(btrim(quantity_unit)) > 0),
 attributes jsonb not null default '{}'::jsonb check(jsonb_typeof(attributes) = 'object'),
 created_at timestamptz not null default now(),
 updated_at timestamptz not null default now(),
 deleted_at timestamptz,
 deleted_by uuid references auth.users(id),
 unique(workspace_id,id),
 foreign key(workspace_id,location_id) references public.locations(workspace_id,id),
 check (
   tracking_mode <> 'individual'
   or (quantity_amount=1 and quantity_unit='piece')
 ),
 check ((deleted_at is null) = (deleted_by is null))
);
create index items_workspace_active_idx on public.items(workspace_id,created_at desc) where deleted_at is null;
create index items_workspace_trash_idx on public.items(workspace_id,deleted_at) where deleted_at is not null;
-- Category/template scope validation is required in a protected function.
-- The server must protect workspace_id, created_by, owner_user_id, audit columns
-- and transition changes; RLS alone does not protect individual fields.

create table public.collections (
 id uuid primary key default gen_random_uuid(),
 workspace_id uuid not null references public.workspaces(id) on delete cascade,
 parent_id uuid,
 title text not null check(length(btrim(title)) > 0),
 description text,
 kind public.curio_collection_kind not null default 'manual',
 filter_spec jsonb check(filter_spec is null or jsonb_typeof(filter_spec) = 'object'),
 created_by uuid not null references auth.users(id),
 created_at timestamptz not null default now(),
 updated_at timestamptz not null default now(),
 deleted_at timestamptz,
 deleted_by uuid references auth.users(id),
 unique(workspace_id,id),
 foreign key(workspace_id,parent_id) references public.collections(workspace_id,id),
 check(parent_id is distinct from id),
 check((deleted_at is null) = (deleted_by is null)),
 check((kind='smart' and filter_spec is not null) or (kind='manual' and filter_spec is null))
);
create index collections_workspace_active_idx on public.collections(workspace_id) where deleted_at is null;
-- Validate smart filter AST server-side; do not execute arbitrary SQL or nested cycles.

create table public.collection_items (
 workspace_id uuid not null,
 collection_id uuid not null,
 item_id uuid not null,
 added_by uuid not null references auth.users(id),
 added_at timestamptz not null default now(),
 primary key(collection_id,item_id),
 foreign key(workspace_id,collection_id) references public.collections(workspace_id,id) on delete cascade,
 foreign key(workspace_id,item_id) references public.items(workspace_id,id) on delete cascade
);
create index collection_items_item_idx on public.collection_items(item_id);

create table public.tags (
 id uuid primary key default gen_random_uuid(),
 workspace_id uuid not null references public.workspaces(id) on delete cascade,
 name text not null check(length(btrim(name)) > 0),
 normalized_name text not null check(length(btrim(normalized_name)) > 0),
 created_at timestamptz not null default now(),
 unique(workspace_id,id),
 unique(workspace_id,normalized_name)
);
create table public.item_tags (
 workspace_id uuid not null,
 item_id uuid not null,
 tag_id uuid not null,
 primary key(item_id,tag_id),
 foreign key(workspace_id,item_id) references public.items(workspace_id,id) on delete cascade,
 foreign key(workspace_id,tag_id) references public.tags(workspace_id,id) on delete cascade
);

create table public.item_identifiers (
 id uuid primary key default gen_random_uuid(),
 workspace_id uuid not null,
 item_id uuid not null,
 scheme text not null check(length(btrim(scheme)) > 0),
 normalized_value text not null check(length(btrim(normalized_value)) > 0),
 display_value text not null,
 created_at timestamptz not null default now(),
 foreign key(workspace_id,item_id) references public.items(workspace_id,id) on delete cascade
);
create index item_identifiers_lookup_idx on public.item_identifiers(scheme,normalized_value);
create index item_identifiers_item_idx on public.item_identifiers(item_id);

create table public.item_media (
 id uuid primary key default gen_random_uuid(),
 workspace_id uuid not null,
 item_id uuid not null,
 storage_path text not null,
 media_type text not null,
 sort_order int not null default 0,
 created_by uuid not null references auth.users(id),
 created_at timestamptz not null default now(),
 unique(storage_path),
 foreign key(workspace_id,item_id) references public.items(workspace_id,id) on delete cascade
);
create index item_media_item_idx on public.item_media(item_id);

create table public.item_sources (
 id uuid primary key default gen_random_uuid(),
 workspace_id uuid not null,
 item_id uuid not null,
 field_key text not null,
 source_kind text not null check(source_kind in ('user','barcode','provider','vision','inference')),
 source_reference text,
 confidence numeric(5,4) check(confidence between 0 and 1),
 recorded_at timestamptz not null default now(),
 foreign key(workspace_id,item_id) references public.items(workspace_id,id) on delete cascade
);

create table public.share_grants (
 id uuid primary key default gen_random_uuid(),
 source_workspace_id uuid not null references public.workspaces(id) on delete cascade,
 resource_type public.curio_share_resource not null,
 item_id uuid,
 collection_id uuid,
 recipient_user_id uuid references auth.users(id),
 recipient_workspace_id uuid references public.workspaces(id),
 permission text not null default 'read' check(permission='read'),
 created_by uuid not null references auth.users(id),
 created_at timestamptz not null default now(),
 expires_at timestamptz,
 revoked_at timestamptz,
 check(
  (resource_type='item' and item_id is not null and collection_id is null)
  or (resource_type='collection' and collection_id is not null and item_id is null)
 ),
 check((recipient_user_id is null) <> (recipient_workspace_id is null)),
 check(recipient_workspace_id is distinct from source_workspace_id),
 check(expires_at is null or expires_at > created_at),
 foreign key(source_workspace_id,item_id) references public.items(workspace_id,id) on delete cascade,
 foreign key(source_workspace_id,collection_id) references public.collections(workspace_id,id) on delete cascade
);
create index share_grants_to_user_idx on public.share_grants(recipient_user_id,revoked_at,expires_at) where recipient_user_id is not null;
create index share_grants_to_workspace_idx on public.share_grants(recipient_workspace_id,revoked_at,expires_at) where recipient_workspace_id is not null;
create index share_grants_item_idx on public.share_grants(item_id) where item_id is not null;
create index share_grants_collection_idx on public.share_grants(collection_id) where collection_id is not null;

create table public.ai_jobs (
 id uuid primary key default gen_random_uuid(),
 workspace_id uuid not null references public.workspaces(id) on delete cascade,
 requested_by uuid not null references auth.users(id),
 kind text not null,
 state public.curio_ai_state not null default 'queued',
 input_reference text,
 sanitized_error text,
 usage_metadata jsonb not null default '{}'::jsonb,
 created_at timestamptz not null default now(),
 completed_at timestamptz,
 unique(workspace_id,id)
);
create index ai_jobs_workspace_idx on public.ai_jobs(workspace_id,created_at desc);

create table public.ai_candidates (
 id uuid primary key default gen_random_uuid(),
 workspace_id uuid not null,
 job_id uuid not null,
 proposed_data jsonb not null check(jsonb_typeof(proposed_data)='object'),
 confidence numeric(5,4) check(confidence between 0 and 1),
 expires_at timestamptz,
 confirmed_at timestamptz,
 created_at timestamptz not null default now(),
 foreign key(workspace_id,job_id) references public.ai_jobs(workspace_id,id) on delete cascade
);

create table public.audit_events (
 id bigint generated always as identity primary key,
 workspace_id uuid not null references public.workspaces(id) on delete cascade,
 actor_id uuid references auth.users(id),
 action text not null,
 subject_type text not null,
 subject_id uuid,
 metadata jsonb not null default '{}'::jsonb,
 created_at timestamptz not null default now()
);
create index audit_events_workspace_idx on public.audit_events(workspace_id,created_at desc);

-- Deny by default. No RLS policy means API users cannot read/write.
-- A subsequent, reviewed policy migration must implement source-membership
-- access, effective share grants, role-checked mutations, and Storage isolation.
alter table public.profiles enable row level security;
alter table public.workspaces enable row level security;
alter table public.workspace_members enable row level security;
alter table public.workspace_invites enable row level security;
alter table public.categories enable row level security;
alter table public.object_templates enable row level security;
alter table public.template_versions enable row level security;
alter table public.locations enable row level security;
alter table public.items enable row level security;
alter table public.collections enable row level security;
alter table public.collection_items enable row level security;
alter table public.tags enable row level security;
alter table public.item_tags enable row level security;
alter table public.item_identifiers enable row level security;
alter table public.item_media enable row level security;
alter table public.item_sources enable row level security;
alter table public.share_grants enable row level security;
alter table public.ai_jobs enable row level security;
alter table public.ai_candidates enable row level security;
alter table public.audit_events enable row level security;

-- Restrict client grants until deliberate policy/action layer is implemented.
-- Supabase role privileges must still be reviewed with a role-aware test suite.
revoke all on all tables in schema public from anon, authenticated;
revoke all on all sequences in schema public from anon, authenticated;

commit;
