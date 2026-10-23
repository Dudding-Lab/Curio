-- Curio – Lending-Architektur (vorbereitet für spätere Ausleihe)
-- Tabellen patrons und loans; RLS analog zu bestehenden Tabellen
-- Status-Ableitung über View möglich

create table public.patrons (
  id uuid primary key default gen_random_uuid(),
  household_id uuid not null references public.households(id) on delete cascade,
  name text not null,
  email text,
  phone text,
  barcode text unique,                 -- optionaler Patron-Barcode / QR
  notes text,
  created_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index patrons_household_id_idx on public.patrons(household_id);

create table public.loans (
  id uuid primary key default gen_random_uuid(),
  household_id uuid not null references public.households(id) on delete cascade,
  item_id uuid not null references public.items(id) on delete cascade,
  patron_id uuid not null references public.patrons(id) on delete cascade,
  status text not null default 'checked_out' check (status in ('checked_out', 'returned', 'overdue', 'reserved')),
  checked_out_at timestamptz not null default now(),
  due_date timestamptz,
  checked_in_at timestamptz,
  notes text,
  created_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index loans_item_id_idx on public.loans(item_id);
create index loans_patron_id_idx on public.loans(patron_id);
create index loans_status_idx on public.loans(status);
create index loans_household_id_idx on public.loans(household_id);

-- updated_at Trigger
create trigger patrons_updated_at
  before update on public.patrons
  for each row execute function public.set_updated_at();

create trigger loans_updated_at
  before update on public.loans
  for each row execute function public.set_updated_at();

-- RLS
alter table public.patrons enable row level security;
