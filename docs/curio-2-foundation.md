# Curio 2.0 — Foundation Specification

Status: Draft v0.1
Date: 2026-11-05
Branch: `planning/curio-2-foundation`
Owner: Product decisions by project owner; technical design subject to review.

## 1. Product vision
Curio is a privacy-conscious, AI-first collection-management application for private users. It supports any type of collectible or household object rather than a predefined media catalog only.

Core experience:
1. Authenticate.
2. Create or select a private workspace or shared household.
3. Create a collection.
4. Capture an object using photo, barcode, identifier, or manual text.
5. Ask AI to propose object type and attributes, enriching them via trusted sources where available.
6. Review and correct suggestions; explicitly save the object.
7. Find, edit, organize, and share it subject to permissions.

AI is assistive, not an authority: all inferred attributes retain provenance and confidence where possible. Users can correct them before saving.

## 2. Initial MVP scope
- Email/password authentication and account logout.
- Private user workspace and shared household workspaces.
- Household invitations with expiring single-use tokens and owner/member permissions.
- Flexible collections and collection-specific attribute schemas.
- CRUD for catalog items with photos, searchable titles, tags, and location association.
- Capture flow: camera/gallery image, barcode/ISBN, manual entry.
- Server-mediated AI candidate extraction with review/confirm before persistence.
- Basic text search, sorting, duplicate warnings, import/export foundation.
- Secure media storage, row-level security, minimal logging, error/loading states.
- Widget/unit tests, SQL/RLS tests, and automated Flutter checks.

Explicitly deferred until the MVP works: full floor-plan editor, rich NFC interactions, valuations, marketplace integrations, advanced lending, public social feeds, complex offline sync, and billing.

## 3. Technical baseline
- Flutter for client application, with Material 3.
- Riverpod for state, go_router for routing.
- Supabase Auth, Postgres, Storage, RLS, migrations and Edge Functions.
- OpenAI accessed ONLY by server-side functions. Never expose service credentials or AI keys in Flutter, web builds, git, or logs.
- Feature-oriented Flutter structure:
  - `lib/app/` initialization, app/router/theme;
  - `lib/core/` configuration, errors, networking and utilities;
  - `lib/features/auth/`, `households/`, `collections/`, `items/`, `capture/`, `ai/`, `search/`;
  - Within each feature, separate presentation/application/domain/data where justified.
- Repositories provide the data-access boundary; widgets must not depend directly on raw PostgREST queries.
- Schema changes via versioned SQL migration files only.
- CI gates: format, analyze, test, migration checks, secret detection, and where possible build.

## 4. Domain model (proposed, NOT migrated)
- `profiles`: user profile metadata (auth.users remains identity source).
- `workspaces`: private or household scope; one or more members.
- `workspace_members`: unique (workspace,user); roles owner/admin/member/viewer.
- `workspace_invites`: hashed token, role, creator, expiry, accepted/revoked timestamps.
- `collections`: workspace, parent collection (optional), name, description, schema reference.
- `collection_templates`: optional reusable data-field templates, with versioning.
- `items`: collection, workspace, label, description, status, optional location, metadata JSONB, timestamps.
- `item_media`: item references to private storage object paths, media kind and ordering.
- `item_identifiers`: barcode/ISBN/serial/etc.; normalized lookup values.
- `item_tags` and `tags`: scoped classification.
- `locations`: workspace-scoped hierarchical places.
- `ai_jobs`: requester, input references, status, sanitized output, cost/rate metadata and timestamps.
- `ai_candidates`: proposed structured attributes with source/provenance, awaiting user review.
- `audit_events`: selective sensitive actions including invite acceptance, permission changes and deletion.

Identifiers: UUID primary keys; foreign keys constrained by workspace. Field-schema validation must happen on trusted backend paths. Prefer additive migrations and document any destructive operation.

## 5. Security and access rules
- Default deny: enable RLS for each user-data table before making it accessible to clients.
- Membership determines access to workspace-scoped objects; never trust a workspace ID supplied by a client alone.
- Owner-only actions: workspace deletion and ownership transfer; confirm destructive operations, document cascade behavior.
- Invitation redemption is atomic, expiration-checked, single-use, resistant to token enumeration and duplicate membership.
- Storage policies enforce workspace membership, upload limits and safe path ownership.
- Backend functions authenticate callers, validate input, rate-limit AI calls and avoid exposing elevated credentials.
- Use provider-published, non-secret client keys only on clients. No passwords, secret keys, database URLs with credentials, or service-role tokens in source code.
- Maintain separate development and production Supabase projects; never execute unreviewed migrations against production.

## 6. AI-assisted cataloging workflow
1. Client uploads image to an authorized private temporary or staging path.
2. Backend verifies user, membership, content type, size, and request quota.
3. Server-side pipeline extracts visual clues/identifiers.
4. Specialized metadata providers may enrich identified objects where permitted.
5. AI generates a strictly structured candidate (object type, title, attribute values, uncertainty, source provenance).
6. Candidate returned to client for user review.
7. User confirms or edits; write item and associated media in an authorized transaction/sequence.
8. Failed or rejected candidate can be retried or discarded; enforce retention controls.

Do not present uncertain AI output as verified fact; keep source attribution and explicit user override.

## 7. Data/privacy principles
- Private by default; all sharing opt-in.
- User-owned collection data with export and deletion paths.
- Limit retained raw imagery and AI inputs; provide clear notices and retention policy.
- No public access to private objects via predictable URLs.
- Avoid sending unnecessary personally identifying data to external AI/metadata providers.

## 8. Delivery sequence and acceptance gates
### F0 — Freeze and audit
- Preserve existing `main` state.
- Inventory repository and all SQL migrations; identify current Supabase environment mismatch.
- Rotate any previously disclosed privileged credentials outside git.
- No destructive production changes.
Acceptance: environment inventory, signed-off migration/RLS audit, clean secrets review.

### F1 — Domain and access foundation
- Implement initial schema/migrations in a separate development environment.
- Add isolation and privilege tests for owners, members, non-members and revoked invitations.
Acceptance: migration succeeds in clean DB; access tests pass.

### F2 — Flutter foundation
- Feature modules, typed repositories, auth-aware navigation, error handling.
- Household and collection flows.
Acceptance: green Flutter analyze/tests and manual smoke checks.

### F3 — First end-to-end item
- Item CRUD, photo attachment, authorized storage, collection detail and search.
Acceptance: different users cannot access each other's objects without membership.

### F4 — First end-to-end AI
- Photo → server analysis → candidate review → persisted item.
Acceptance: failing AI service does not lose user data; no server secret reaches client.

### F5 — Beta hardening
- CI, accessibility, import/export, performance, privacy, recovery and real-device testing.
Acceptance: release checklist signed off.

## 9. Architecture decisions to confirm
- Whether private collections use an automatic personal workspace or an independent ownership model. Recommendation: personal workspace.
- Whether an item can belong to multiple collections. Initial recommendation: one canonical collection with tags; extend with many-to-many if validated by usage.
- Whether configurable fields use typed EAV or JSONB with versioned schemas. Initial recommendation: JSONB plus validated schema and indexed common columns.
- AI provider budgets and storage retention.
- Minimum target platforms for first beta.

## 10. Existing repository compatibility
The current `main` README refers to an older Supabase project; the correct environment must be confirmed before any migration is executed. Existing `households` and `collections` screens are a reference only, not proof of backend completeness. No production schema change is authorized by this document.

## 11. Next change set
1. Inventory migrations, current policies, assets, CI, and test state.
2. Add Architecture Decision Records (ADRs) for workspace ownership, collection model, and AI trust boundary.
3. Implement development-only versioned schema after review.
4. Add tests for workspace isolation and invitations.
5. Start new Flutter modules on a separate implementation branch and submit PR.
