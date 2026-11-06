# Kovunela – Secure manual saving, implementation gate

Status: **Flutter implementation complete behind a disabled-by-default compile flag.**
Backend: Supabase Curio project `tgawxheqrcqhcvxaexvd`, non-production.

## Database changes confirmed, 2026-11-06
- Migration `kovunela_restrict_create_rpc_to_authenticated` applied.
- Read and create RPC privilege checks now show `anon` cannot execute either endpoint; `authenticated` can.
- Private workspaces/items remain in the unexposed `kovunela` schema, RLS enabled and without client table policies.
- Internal privileged functions use a fixed search path and server-derived `auth.uid()` identity.

## Flutter change
- `ManualCaptureScreen` reviews a required title and optional description.
- New `KOVUNELA_ENABLE_PERSONAL_ITEM_SAVE` compile-time flag gates the Save button. **Default is false**; current user-facing product remains safe and non-writing.
- When explicitly enabled in a controlled environment, the view calls `SupabasePersonalItemRepository.create` (authenticated `public.kv_create_personal_item` RPC) and navigates to `/items` only after an ID is confirmed.
- During save the action is disabled to prevent duplicate taps; failures keep the draft intact, show a localized error and permit retry. The server RPC is not idempotent across network retries, so do not retry automatically.
- Repository injection allows isolated widget tests; mocked-success tests are NOT proof of real backend authorization.

## Gate before turning the flag on by default
1. Add a **second independent Supabase Auth test account** through standard signup, without manipulating `auth.users` directly.
2. Test two genuine JWT sessions A and B using the supported Data API: A creates item; A lists it; B cannot list it or modify it; anonymous create/list denied.
3. Validate malformed title/description rejection and forced cross-workspace access; check actual PostgREST exposed schema settings.
4. Review concurrency/idempotency, network timeouts and duplicate server submissions.
5. Run latest CI; restore strict Dart formatting gate before merging.
6. Continue with full household/collection schema separately; **do not** use legacy household IDs as Kovunela workspace IDs.
7. Investigate pre-existing legacy security advisor findings before public deployment.

In this stage no Auth account or legacy table was deleted and no test user was created.
