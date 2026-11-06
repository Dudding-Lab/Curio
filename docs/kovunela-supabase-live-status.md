# Kovunela — Supabase checkpoint, 6 November 2026

## Connected project
Supabase **Curio**: `tgawxheqrcqhcvxaexvd`. Existing `public` legacy tables and one Auth user preserved.

## Applied and verified
- `20261106052038_kovunela_additive_private_workspace_item_foundation`: private `kovunela.workspaces`, `kovunela.workspace_members`, `kovunela.items`, all with RLS enabled and no direct policies; protected personal workspace/item-create functions and `public.kv_create_personal_item` wrapper.
- `20261106060542_kovunela_list_private_items`: initial listing API.
- `20261106060553_kovunela_private_item_list_wrapper`: moves privileged listing into unexposed schema `kovunela`, replaces public listing endpoint with `SECURITY INVOKER`.
- Read API: `public.kv_list_personal_items()` returns up to 100 non-deleted items owned by the authenticated caller's personal workspace.
- Permission check: `anon` **cannot** execute the listing RPC; `authenticated` can. A catalog query confirmed the public wrapper is not SECURITY DEFINER; the internal implementation is SECURITY DEFINER. No direct table grants were added.
- Flutter repository now supports typed `list()` and the signed-in route `/items` displays an empty, loading, error or populated state as appropriate.

## Still pending and NOT claimed as tested
- Real REST/RPC calls using two independent valid user sessions (only one Auth user was present in inspection).
- Verify that user A cannot list user B's items, and that no anonymous caller can create or list items; exercise validation and retries.
- Enable item creation in Flutter only after authenticated cross-user integration checks pass.
- Confirm data API schema settings expose `public` and do **not** expose `kovunela`.
- Introduce the rest of full universal-collection schema and role-managed households.
- Resolve pre-existing legacy security-advisor findings before any release.
- Preserve migration SQL as a reviewed tracked baseline: the live Supabase migrations exist but are not yet reproduced as checked-in SQL migrations. The original prototype SQL in docs is **not** identical to the deployed schema.

## Security advisor findings
- New `kovunela` tables: RLS enabled, no policies (intentional: internal-only and deny by default).
- Legacy: `public.item_loan_status` security-definer view; legacy executable SECURITY DEFINER functions; mutable function search_path; some legacy tables have RLS with no policies.
- References: https://supabase.com/docs/guides/database/database-linter?lint=0010_security_definer_view and https://supabase.com/docs/guides/database/database-linter?lint=0028_anon_security_definer_function_executable

## Change boundary
No legacy application tables, Auth users or project config were deleted or modified. A destructive reset was blocked by host safety controls and should not be retried by circumvention. The new phase is additive, isolated and reversible after explicit review.
