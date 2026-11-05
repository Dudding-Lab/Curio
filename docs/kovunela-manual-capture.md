# Kovunela – Manual item capture, phase 1

Status: implemented in feature branch as **form + review ONLY**. No data is saved yet.

## User flow
1. Signed-in user selects "Enter manually" on Home or the "Capture" navigation destination.
2. User enters a required item title and optional description.
3. Form validates the title, normalizes whitespace and shows a review screen.
4. User can edit the draft or see a disabled Save button and a clear explanation that secure persistence is not ready.
5. The form is intentionally independent of collections.

## Why persistence is disabled
The new architecture stores items in `public.items` linked to a personal/household `workspace_id`. The table, automatic personal-workspace provisioning and RLS/write policies are currently **only designed**, not deployed or tested. Legacy `households` and `collections` are not interchangeable with this model.

Do not attempt a client-side insert against a half-migrated database or silently attach an item to a guessed/default household. Do not enable Save until:
- Isolated Supabase development project contains reviewed schema migrations.
- On signup, a personal workspace is created and the user receives a verified owner membership.
- Server-side write authorization enforces membership, permitted roles, trusted `created_by`/workspace fields and soft-deletion rules.
- An authorized item-create operation is transactional and tested for valid/invalid cross-workspace access, untrusted fields, and empty collections.
- The user chooses the target workspace where necessary, with private workspace as safe default.
- UI shows a real saved item only after successful server acknowledgment; error states preserve draft.
- Tests verify the full transaction and RLS using at least two users.

## Phase 2
Once these prerequisites pass in development, implement `ItemRepository` with a secure Supabase RPC/Edge Function or reviewed RLS insert policy. Return a typed result ID; never claim persistence before server confirmation. Add workspace choice, item detail and listing as a complete vertical slice. Introduce photo/barcode/AI suggestions separately, with user confirmation before creating authoritative records.

## Testing
`flutter test` covers draft validation and the review-only UI. Check CI before merging. Preserve the legacy app behavior. No production Supabase schema, DNS, release or repository rename changes in this package.
