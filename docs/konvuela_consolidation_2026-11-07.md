# Konvuela consolidation baseline — 2026-11-07

## Decision and scope

Workshop decisions 01/02: `kovunela` is the authoritative private collection model; `kovunela_catalog` is the private global catalog/review pipeline; public `kv_*` RPC functions are the client-facing contract. The legacy `public.households`, `public.collections`, `public.items`, etc. are retained for compatibility and **must not** be dropped as part of this work.

Target project: Supabase project ref `tgawxheqrcqhcvxaexvd`; GitHub `Dudding-Lab/Curio`. This document contains no credentials or user records.

## Read-only database baseline verified

- PostgreSQL 17, active project.
- 13 `kovunela` tables; 7 `kovunela_catalog` tables; 16 legacy public tables.
- New private schemas have no direct table SELECT/INSERT grants for `anon` or `authenticated`.
- `authenticated` has USAGE on `kovunela` for authorized function invocation; `anon` does not.
- Client-facing `public.kv_*` RPC wrappers are principally `SECURITY INVOKER` and limited to `authenticated`.
- Private implementation functions predominantly use `SECURITY DEFINER`, `search_path=''`, and explicit `auth.uid()`/workspace ownership checks; this **requires** multi-user security regression testing.
- Active Edge Functions: `kovunela-books-lookup`, `kovunela-vision-analyze`, both with JWT verification required.
- Active cron jobs: `kovunela-catalog-stage-pending` every minute and `kovunela-catalog-identifier-review` every two minutes.
- New schema's migrations through `20261107113518_standard_item_invoker_wrapper` already exist remotely but are **not** represented by the legacy repository's October SQL history. Do not run `supabase db push` from this repository against production until that migration divergence is reconciled.
- First security correction deployed in production as `20261107195644_konvuela_restrict_legacy_household_trigger_execution`. Verified both anonymous and authenticated direct EXECUTE = false; original trigger remains present.

## GitHub baseline / reversible implementation

- Branch: `chore/konvuela-consolidation-20261107`, created from main at `eec7306ea0ba69878a0555ad98504fbf73206c9c`.
- Legacy routes remain in place. A separate `/konvuela` route exposes new personal collection/item reads and personal collection creation via public RPC wrappers.
- No private schema table is queried directly by Flutter.
- This is an integration scaffold, NOT a tested release. Flutter/Dart SDK was unavailable in the execution environment; there is no verified build or device test.

## Backups, safety, and release gate

- Creating a Git branch is a **source-code restore point**, not a PostgreSQL data backup.
- A full independently restorable production database backup has **not** been created or verified through the available Supabase connector. Verify Supabase-managed backup coverage or perform an approved `pg_dump` to an encrypted private destination before broader schema changes. Never commit raw data or secrets to the public repository.
- The applied REVOKE is reversible and does not change any rows or tables. Remaining role/helper and view findings remain open until isolated tests pass.
- Verify migrations against the actual production migration history before backfilling repo files; do not fabricate migration contents.
- Rotate formerly supplied secret credentials through the project's secure administrative workflow and update their consumers in a coordinated cutover; the public publishable key is not secret.

## Outstanding high-priority checks

1. Confirm the real production database has a tested restorable backup.
2. Inspect JWT, anonymous role, cross-user, and cross-workspace permission boundaries using two test accounts.
3. Audit legacy `has_household_role` and `is_household_member` grants before restricting them because existing RLS policies depend on them.
4. Audit `public.item_loan_status` (security-definer view) and restrict/replace safely.
5. Decide policy on automatic private-item staging in global catalog; document data minimization and user-facing consent.
6. Reconstruct actual deployed schema/migrations and deployed Edge Function source into reproducible versioned artifacts, without user data or secrets.
7. Build Flutter Android/iOS/Web, validate JWT initialization, exercise `/konvuela` for two test users, then add detail/edit/delete and template-backed item creation.
8. Check source repository, CI and logs for secrets; rotate any exposed privileged tokens.

## Verified client contract (2026-11-07)

- `kv_list_personal_collections()` -> rows `id, title, description, created_at`
- `kv_create_personal_collection(p_title,p_description)` -> uuid
- `kv_list_personal_items()` -> rows `id, title, description, created_at`
- `kv_create_personal_item(p_title,p_description)` -> uuid
- `kv_list_standard_templates()` -> standard template listing
- All four personal-resource RPCs are intentionally independent of legacy `public.collections` and `public.items`.

## Rollback

- Frontend scaffold: do not merge the draft PR, or revert its commits if merged.
- Applied migration: granting `EXECUTE` on `public.handle_new_household()` back to `PUBLIC` restores the previous privilege state, but do so only for a verified compatibility need; the trigger continues functioning without client EXECUTE rights.
- No legacy data or table has been removed.
