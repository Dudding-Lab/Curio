# Kovunela phase-1 backend – isolation and acceptance checklist

**Status: proposed SQL in docs ONLY. NOT executed, NOT tested against PostgreSQL, NOT deployed.**

## Files and relationship to architecture
- `docs/sql/kovunela_phase1_dev_only.sql` is a **small, isolated proof-of-concept** for manual item storage: `workspaces`, `workspace_members`, `items` plus three protected functions.
- `docs/sql/curio_v2_schema_proposal.sql` is the separate **full schema proposal** with 20 tables. The phase-1 proof of concept does NOT replace it. Reconcile tables, type choices, updates, role semantics and constraints before creating any production migrations.
- No legacy migrations or live database schema has been verified exhaustively. Existing tables may conflict with these names. **Never paste this script into an existing project**.

## Function contract
1. `kv_ensure_personal_workspace() -> uuid` identifies caller from `auth.uid()`, transactionally creates their one personal workspace if absent, ensures owner membership and returns ID.
2. `kv_create_personal_item(p_title text, p_description text) -> uuid` validates input, obtains caller personal workspace and inserts a single item. Workspace ID / creator are server-generated, not client input.
3. `kv_is_workspace_member(workspace_id uuid) -> boolean` supports read-only RLS checks without recursive membership policies.
4. The public tables permit authenticated SELECT with workspace RLS, no direct untrusted INSERT/UPDATE/DELETE; writes require explicit RPC.
5. First slice intentionally excludes household writes, collection association, file storage, soft delete and update; these require security review.

## Before ANY execution
- Create a **new, isolated** Supabase DEV project with no unrelated data and separate secrets.
- Confirm with the project owner which environment is non-production. Never ask for service-role keys or credentials in a chat.
- Review SQL with a Postgres/Supabase-aware security reviewer, including `security definer` owner and grants.
- Run script in isolated DB and verify PostgreSQL errors; no execution has happened yet.
- Check generated API schema exposure and public RPC permissions via PostgREST.

## Security validation matrix – mandatory before enabling Flutter Save
Use two independent Auth users A and B created in the isolated development project; keep both sessions and test via ordinary authenticated Supabase clients, not a SQL-editor superuser.

| Scenario | Expected |
|---|---|
| Anonymous invoke `kv_ensure_personal_workspace` | Denied |
| Anonymous invoke `kv_create_personal_item` | Denied |
| A creates workspace twice | Same UUID, exactly one personal workspace for A |
| B creates workspace | Different UUID, one membership for B |
| A inserts item by `kv_create_personal_item` | One row, `created_by = A`, workspace owner A |
| B reads `items` | Cannot see A's item |
| B guesses A's workspace UUID | B cannot read A's workspace or membership |
| A or B attempts direct table insert/update/delete | Denied |
| A tries to insert title empty or >200 characters | Denied with predictable validation error |
| A tries description >5000 characters | Denied |
| A can't specify B's workspace/created_by through the RPC | No such parameters |
| Malicious nonmember calls member-check function | Returns false |
| Disabled or unauthenticated session invokes functions | Denied |

### Additional checks
- Validate `auth.uid()` is reliable under real REST/RPC calls.
- Verify SECURITY DEFINER functions cannot be exploited through search path, role membership or user-supplied identifiers; only owner-controlled objects are accessed.
- Test session expiry, retries and network failure. Never show a saved item unless the RPC returns success.
- Verify RLS scope with multiple workspaces and role combinations before expanding to shared households.
- Verify an input over 200 Unicode code points is rejected consistently by UI and SQL.
- Confirm idempotent provisioning behavior under concurrent calls from same account.
- Detect performance regressions for membership-based RLS and pagination.

## Flutter integration gate
The manual draft/review screen **must remain read-only** until a separate development Supabase environment is available, this validation matrix passes, and a secure client repository is integrated. Do not silently redirect to legacy `households` or `collections`.

## Planned follow-up
After isolated validation, convert the approved SQL into a versioned migration that is part of a coherent schema, implement typed item repository, connect Save to the verified RPC, render real items and test two-user RLS. Maintain a clear migration path for full universal collection model.


## Product-owner decision — replace non-production legacy data (2026-11-06)
The existing Supabase project has **never been used in production**. The owner explicitly permits overwriting the existing **application test data and legacy application tables** for the Kovunela redesign. No migration or preservation of old household/collection test content is required.

Revised strategy:
1. **Do not require a second paid Supabase project.** Reuse the existing project for a clean-slate application schema when confirmed accessible, after identifying its exact project and enumerating objects.
2. First inventory current SQL schema, RLS policies, RPCs, triggers, Storage buckets and Edge Functions; compare against the full Curio v2 model. Avoid applying the narrow phase-one draft alongside conflicting legacy tables.
3. Prefer **one coherent versioned baseline** for the full Kovunela model and a reviewed transition/reset script, followed by security tests, over disconnected trial migrations.
4. Before destructive execution, verify an optional backup/export or explicitly record that test data will be lost, and obtain an environment-specific go-ahead for the exact reset operation. Confirm this is not a shared or production database.
5. Legacy **Auth users**, sign-in identities, secrets, deployed Edge Functions, Storage objects and project configuration are **not automatically covered** by permission to replace data. Preserve them unless explicitly included and confirmed in a precise reset plan.
6. Nothing in this document means a database reset has happened. There is no direct Supabase execution connection in the current tooling. GitHub changes are not deployments.
