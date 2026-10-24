-- Curio – Automatisches Hinzufügen des Erstellers als Owner
-- Stellt sicher, dass der created_by-Nutzer sofort Mitglied des Haushalts ist
-- und die RLS-Select-Policy greift.

create or replace function public.handle_new_household()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.household_members (household_id, user_id, role)
  values (new.id, new.created_by, 'owner');
  return new;
end;
$$;

drop trigger if exists on_household_created on public.households;

create trigger on_household_created
  after insert on public.households
  for each row execute function public.handle_new_household();

comment on function public.handle_new_household() is 'Fügt den Ersteller eines Haushalts automatisch als Owner in household_members ein';
