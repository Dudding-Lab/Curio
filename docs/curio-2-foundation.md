# Curio 2.0 — Foundation Specification

Status: Draft v0.2 — product choices B (AI-assisted confirmation) and C (extensible intelligent templates) accepted
Date: 2026-11-05
Branch: `planning/curio-2-foundation`
Owner: Product decisions by project owner; technical design subject to review.

## 1. Product vision
Curio is a privacy-conscious, AI-first collection-management application for private users. It supports any type of collectible or household object rather than a predefined media catalog only.

Core experience:
1. Authenticate.
2. Create or select a private workspace or shared household.
3. Optionally create a collection; items can exist without one.
4. Capture an object using photo, barcode, identifier, or manual text.
5. Ask AI to propose object type and attributes, enriching them via trusted sources where available.
6. Review and correct suggestions; explicitly save the object.
7. Find, edit, organize, and share it subject to permissions.

AI is assistive, not an authority: all inferred attributes retain provenance and confidence where possible. Users can correct them before saving.

## 2. Initial MVP scope
- Email/password authentication and account logout.
- Private user workspace and shared household workspaces.
- Household invitations with expiring single-use tokens and owner/member permissions.
- Flexible collections with reusable, versioned intelligent object templates and user-defined typed fields.
- Items may exist without a collection and can be linked to multiple collections within the same workspace.
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
- `collections`: workspace, optional parent, name, description, manual vs saved-filter mode.
- `collection_templates`: optional reusable data-field templates, with versioning.
- `items`: canonical physical/individually managed item record; workspace, optional owner, title, description, status, optional location, structured metadata JSONB, template/version and timestamps. No mandatory collection FK.
- `collection_items`: many-to-many (collection_id, item_id) unique join with enforced same-workspace membership.
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
- CONFIRMED: objects may exist without a collection and may be linked to multiple collections in the same workspace. Cross-workspace visibility requires explicit, separately authorized sharing, not foreign-key reuse.
- CONFIRMED: intelligent, versioned templates with extensible typed attributes. Proposed physical representation: JSONB attributes plus field definitions and validation, indexed common columns. Benchmark query needs before final migration.
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

## 12. Confirmed product decisions (2026-11-05)
- **C — Universal AI-first platform:** collections, personal inventory and shared household use one object model.
- **B — AI-centric onboarding:** capture first, organization later; no required collection before capturing an item.
- **B — Assisted automation:** AI offers categorization, field values and collection suggestions; user reviews and confirms before writing. Automatic organizational rules require separate explicit opt-in.
- **C — Intelligent extensible templates:** Curio proposes category-specific templates; users may add/edit custom typed properties or save their own template. Templates cannot silently overwrite existing item values.
- An item has one canonical record and zero or more collection memberships in the same workspace; category, tags, physical location and collection memberships are independent axes.
- Workspaces isolate personal vs shared data. Membership does not disclose personal records to a household.

## 13. Detailed proposed data model (design, not SQL migration)

### 13.1 Accounts, workspaces and sharing
| Table | Essential fields and invariants |
|---|---|
| profiles | user_id PK/FK auth.users; display_name, locale, created_at |
| workspaces | id PK, kind personal/household, name, created_by, created_at, deleted_at; exactly one personal workspace per user enforced |
| workspace_members | workspace_id, user_id composite unique; role owner/admin/editor/viewer; status active; joined_at; cannot remove final active owner |
| workspace_invitations | id, workspace_id, invited_email optional, role, token_hash UNIQUE, expires_at, accepted_at, revoked_at, created_by; single-use atomic accept |
| share_grants (deferred) | scoped object/collection share to identity/group with explicit allowed operations and expiry; cross-workspace sharing via grants, not unsafe duplicate workspace membership |

Personal workspaces are private by default, including when the user joins household workspaces. The optional `owner_user_id` on an item is provenance/ownership metadata and is not sufficient by itself to grant workspace access; sharing must be explicitly authorized.

### 13.2 Universal items
| Table | Essential fields and invariants |
|---|---|
| items | id, workspace_id, title, description, category_id nullable, template_version_id nullable, created_by, owner_user_id nullable, location_id nullable, condition nullable, acquired_on nullable, currency nullable, purchase_amount nullable, attributes jsonb DEFAULT '{}', status, created_at, updated_at, deleted_at |
| item_media | id, workspace_id, item_id, storage_path, media_type, sort_order, created_by, created_at |
| item_identifiers | id, workspace_id, item_id, scheme (ISBN/EAN/UPC/serial/custom), normalized_value, display_value, issuer optional; avoid global unique constraint on barcode because multiple owned copies may share it |
| tags | id, workspace_id, label, normalized_label; scoped unique |
| item_tags | workspace_id, item_id, tag_id; composite unique |
| locations | id, workspace_id, parent_id nullable, name, kind, created_at; prevent cycles |
| item_relations (later) | from_item_id, to_item_id, type; same-workspace constraint; e.g. part_of, accessory_of |
| catalog_entities (later) | shared normalized product/work metadata; owned items remain individual records even when referencing the same ISBN/product model |

Every child entity that carries `workspace_id` must be constrained to match its parent. Use composite foreign keys such as `(workspace_id,item_id) REFERENCES items(workspace_id,id)` alongside the appropriate unique index. Same applies to location, collection, tag, and template references. Do not rely solely on client validation.

### 13.3 Collections and flexible templates
| Table | Essential fields and invariants |
|---|---|
| collections | id, workspace_id, parent_id nullable, title, description, kind manual/smart, filter_spec jsonb nullable, created_by, created_at, updated_at, deleted_at |
| collection_items | workspace_id, collection_id, item_id, added_at, added_by; unique (collection_id,item_id) |
| categories | id, scope global/workspace, workspace_id nullable, parent_id nullable, code, label; curated suggestions + custom categories |
| object_templates | id, scope global/workspace, workspace_id nullable, name, category_id nullable, created_by; stable logical identity |
| template_versions | id, template_id, version int, published_at, field_schema jsonb, immutable once published; unique (template_id,version) |
| field_definitions | optional relational registry for custom fields, stable field_key, data_type (text/number/boolean/date/enum/money/url/reference), constraints jsonb, display_order |
| saved_views (later) | user/workspace, filter_spec jsonb, sort_spec jsonb; power smart collections without untrusted raw SQL |

Store universal indexed fields in columns, flexible typed values in `items.attributes`. Enforce JSON schema and allowed field keys/types in trusted write paths; record template version on each item. Template edits create a new version and do not rewrite prior records without user-approved migration. For smart collections, evaluate validated allowlisted filter AST; never execute user-supplied SQL.

### 13.4 AI and provenance
| Table | Essential fields and invariants |
|---|---|
| ai_jobs | id, workspace_id, requested_by, kind, state, request_fingerprint, created_at, completed_at, usage/cost metadata, sanitized_error |
| ai_candidates | id, job_id, workspace_id, proposed_category, proposed_template_version, attributes jsonb, confidence/uncertainty, expires_at, confirmed_at |
| attribute_sources | id, workspace_id, item_id nullable, candidate_id nullable, field_key, source_kind user/barcode/provider/vision/inference, source_reference nullable, confidence nullable, recorded_at |
| audit_events | id, workspace_id, actor_id, action, subject_type, subject_id, created_at, minimal metadata; avoid leaking protected values |

AI proposals are not persisted as item facts until explicit confirmation. A review screen must distinguish high-confidence extracted values, externally verified provider facts, and heuristic guesses. All server-side providers use server credentials only. Validate model output before creating records.

## 14. Authorization policy matrix (business rules)
Roles are scoped to the target workspace; personal workspace has one owner only. Policies below apply only within an authorized workspace.

| Operation | Owner | Admin | Editor | Viewer | Non-member |
|---|---|---|---|---|---|
| Read workspace inventory/collections | yes | yes | yes | yes | no |
| Create/edit items, add media, manage tags/collections | yes | yes | yes | no | no |
| Delete/restore ordinary items | yes | yes | yes (subject to policy) | no | no |
| Invite/manage membership (non-owner roles) | yes | yes | no | no | no |
| Change workspace settings | yes | yes | no | no | no |
| Transfer ownership; delete workspace | yes, explicit confirmation | no | no | no | no |
| Access AI extraction for allowed items | yes | yes | yes | no (MVP) | no |
| Export entire workspace | yes | yes | no | no | no |

Further principle: a separate owner_user_id field does not override permissions. Future object-level shares must be implemented as additive, narrowly scoped grants and independently tested, not by weakening workspace RLS.

### RLS / server enforcement
1. `auth.uid()` comes from authenticated JWT; do not trust client-provided actor or role.
2. Default deny; enable RLS on all user-data tables, with explicit SELECT/INSERT/UPDATE/DELETE policies.
3. Centralize active-membership and role checks in carefully audited SQL helpers. Watch SECURITY DEFINER search_path and function execution grants.
4. Prefer direct authenticated-client writes only where policies and constraints suffice; use transaction-safe RPC for invitation redemption, owner transfers, compound item creation, deleting a workspace, and similar multi-step privileged actions.
5. Do not allow updating workspace_id or owner/privileged metadata by ordinary item update; avoid cross-tenant moves by construction.
6. Membership can never see anything in another workspace, including storage, AI jobs, tags or related lookup rows.
7. Storage is private; generate short-lived signed URLs only after authorization or enforce verified storage RLS. Restrict content type, size, path, and lifecycle of staging uploads.
8. Privileged writes produce tamper-resistant audit events, with limited exposure and retention.

### Critical adversarial tests
- Unauthenticated access to every user-data table returns nothing/denied.
- User B cannot read/change User A's personal items or storage.
- Household viewer cannot insert, update or delete item/collection; editor cannot invite.
- Removing membership immediately blocks read/write, signed URL issuance and AI jobs.
- Cross-workspace collection-item / item-location / item-tag / media attachment IDs are rejected by database constraints.
- Last owner cannot be removed; ownership transfer is atomic.
- Invites are expired, single-use, hashed, bounded by role and cannot be replayed.
- AI cannot silently modify confirmed values, permissions, ownership or locations.
- Smart-filter AST cannot inject arbitrary SQL.
- Storage staging files expire; rejected candidate cannot be used to access someone else's image.

## 15. Implementation contract and decisions pending validation
- Design first; DO NOT run any migration against a production or legacy Supabase project.
- Before SQL migration: audit all existing migrations/policies and resolve contradictory project references in documentation.
- New development database: create versioned SQL migration, indices, foreign keys and RLS plus database access regression tests.
- Explicitly choose whether members may delete items they did not create; above matrix currently allows editors under normal item rules.
- Clarify GDPR deletion/export retention, shared-object owner semantics, invitation email behavior, and storage limits.
- Keep catalog entity normalization, smart collections, object-level share grants and complex offline synchronization out of first release unless validated.
