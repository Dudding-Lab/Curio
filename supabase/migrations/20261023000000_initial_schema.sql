-- Curio – Initiales Datenmodell (erweitert)
-- Erstellt für den Neustart des Projekts
-- Alle Tabellen mit RLS, saubere Beziehungen, Indexes
-- Erweiterungen: vordefinierte Metadaten, Standortmodell (Liste + Grundriss), NFC/RFID, Reihen/Serien

-- Extensions
create extension if not exists "uuid-ossp";

-- =============================================================================
-- HOUSEHOLDS
-- =============================================================================
create table public.households (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  created_by uuid not null references auth.users(id) on delete cascade,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index households_created_by_idx on public.households(created_by);

-- =============================================================================
-- HOUSEHOLD MEMBERS
-- =============================================================================
create table public.household_members (
  household_id uuid not null references public.households(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  role text not null check (role in ('owner', 'admin', 'member', 'viewer')),
  joined_at timestamptz not null default now(),
  primary key (household_id, user_id)
);

create index household_members_user_id_idx on public.household_members(user_id);

-- =============================================================================
-- HOUSEHOLD INVITES
-- =============================================================================
create table public.household_invites (
  id uuid primary key default gen_random_uuid(),
  household_id uuid not null references public.households(id) on delete cascade,
  email text,
  token_hash text not null unique,
  expires_at timestamptz not null,
  created_by uuid not null references auth.users(id) on delete cascade,
  accepted_at timestamptz,
  created_at timestamptz not null default now()
);

create index household_invites_household_id_idx on public.household_invites(household_id);
create index household_invites_token_hash_idx on public.household_invites(token_hash);

-- =============================================================================
-- COLLECTIONS
-- =============================================================================
create table public.collections (
  id uuid primary key default gen_random_uuid(),
  household_id uuid not null references public.households(id) on delete cascade,
  name text not null,
  description text,
  created_by uuid not null references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index collections_household_id_idx on public.collections(household_id);

-- =============================================================================
-- LOCATIONS (für „Wo ist“ – Liste und interaktiver Grundriss)
-- =============================================================================
create table public.locations (
  id uuid primary key default gen_random_uuid(),
  household_id uuid not null references public.households(id) on delete cascade,
  name text not null,
  type text not null check (type in ('room', 'shelf', 'position', 'other')),
  parent_id uuid references public.locations(id) on delete set null,
  floor_plan_data jsonb not null default '{}'::jsonb, -- z. B. {x, y, image_path, notes}
  sort_order integer default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index locations_household_id_idx on public.locations(household_id);
create index locations_parent_id_idx on public.locations(parent_id);

-- =============================================================================
-- ITEMS
-- =============================================================================
create table public.items (
  id uuid primary key default gen_random_uuid(),
  collection_id uuid not null references public.collections(id) on delete cascade,
  title text not null,
  description text,
  -- Vordefinierte Metadaten für Bücher und Medien
  isbn text,
  authors text,                    -- Autor / Künstler / Regisseur (kommagetrennt oder freier Text)
  publication_year integer,
  genre text,
  publisher text,                  -- Verlag / Label
  format text,                     -- Format / Medium
  condition text,                  -- Zustand
  language text,
  -- Reihen / Serien
  series_name text,
  volume_number text,
  -- Identifikation und Standort
  nfc_tag_id text unique,          -- NFC-/RFID-Tag-ID
  location_id uuid references public.locations(id) on delete set null,
  -- Flexible und individuelle Metadaten
  metadata jsonb not null default '{}'::jsonb,
  created_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index items_collection_id_idx on public.items(collection_id);
create index items_nfc_tag_id_idx on public.items(nfc_tag_id);
create index items_location_id_idx on public.items(location_id);
create index items_isbn_idx on public.items(isbn);
