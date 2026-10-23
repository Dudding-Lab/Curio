# Schema-Readiness Check

Führen Sie dieses Skript im Supabase SQL Editor aus, um zu prüfen, ob alle Kern-Tabellen existieren.

```sql
select
  to_regclass('public.households') as households,
  to_regclass('public.household_members') as household_members,
  to_regclass('public.household_invites') as household_invites,
  to_regclass('public.collections') as collections,
  to_regclass('public.locations') as locations,
  to_regclass('public.items') as items,
  to_regclass('public.media_assets') as media_assets,
  to_regclass('public.ai_jobs') as ai_jobs,
  to_regclass('public.patrons') as patrons,
  to_regclass('public.loans') as loans;
```

Erwartetes Ergebnis: Alle Spalten zeigen den Tabellennamen (nicht `null`).

## Empfohlene Reihenfolge nach dem Neustart

1. Neues Supabase-Projekt anlegen
2. Migration `20261023000000_initial_schema.sql` anwenden
3. Schema-Readiness prüfen
4. Flutter-Projekt mit Auth und Household-Liste starten
5. Invite-Flow (Edge Functions) hinzufügen
6. Collections & Items
7. Media Storage + Upload
8. AI Jobs
