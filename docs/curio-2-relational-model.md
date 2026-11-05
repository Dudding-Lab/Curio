# Curio 2.0 — Relational model and authorization contract
Status: product decisions FINAL; schema DRAFT for code review and isolated development testing
Date: 2026-11-05
Source of truth: `docs/curio-2-foundation.md`, §12–16
Target: PostgreSQL / Supabase Auth + Storage with RLS

## 1. Fundamental invariants
1. Each auth user has one automatically provisioned **personal workspace**, which no other user joins. Users may join zero or more household workspaces.
2. A canonical `item` belongs to exactly one source workspace. Its `owner_user_id` records ownership, not a substitute for access policies. Cross-workspace access is a grant, **never** an implicit move or duplication.
3. A canonical item belongs to zero or more manual collections of its **source workspace**. `collection_items` is many-to-many. Removing a collection doesn't remove an item.
4. Categories, tags, locations and templates are separate independent organizational dimensions. Template versions are immutable. User metadata stored in JSONB is validated against a versioned typed schema in trusted write paths.
5. AI result candidates are isolated from confirmed item records. No AI job can publish changes, grant access or delete an item without a user action.
6. Deletion means placing records in trash, recording `deleted_at` and `deleted_by`. Authorized editors may trash and restore ordinary objects; they may never purge. Related collection membership and media references are preserved during recoverability window.
7. Two item tracking modes: `individual` (quantity 1 piece) and `quantity` (positive numeric amount/unit). A lot has homogeneous owner, location, condition and attributes. Changes to quantity must be transaction-safe. Later stock movement ledger is compatible.
8. Invitations and share grants expire/revoke without changing data ownership. Privileges are evaluated dynamically and cannot grant access beyond source content visibility for the granting actor.

## 2. Entities and important columns

### Identity and workspaces
- `profiles`: `user_id` (PK, auth.users), display name, locale and timestamps.
- `workspaces`: `id` (PK), `kind` personal|household, `created_by`, `name`, timestamps; partial UNIQUE personal(workspace creator).
- `workspace_members`: composite PK (`workspace_id`,`user_id`), role owner|admin|editor|viewer; FK auth.users and workspace. One final owner must remain; role changes restricted to privileged transactional endpoints.
- `workspace_invites`: PK, workspace, creator, intended recipient identity or email, target role, hashed bearer token, created/expiry/accepted/revoked fields; atomic single-use redemption with bounded scopes.

### Content
- `categories`: global curated and workspace-local category tree, stable code.
- `object_templates`: global curated and workspace-local logical templates.
- `template_versions`: (`template_id`, `version`) UNIQUE, immutable JSON schema; validate allowed types, names, required keys and bounds.
- `locations`: workspace-scoped hierarchy; cycles disallowed.
- `items`: PK; workspace; category/template version; creator and optional recorded owner; title, description, condition, optional location; tracking mode; quantity amount and unit; `attributes jsonb`; created/updated; `deleted_at`/`deleted_by`.
- `collections`: workspace, optional same-workspace parent, kind manual or smart, title, `filter_spec` only for smart views, deletion markers.
- `collection_items`: same-workspace many-to-many manual association and provenance. Smart collections are query-defined and don't take explicit membership.
- `tags`, `item_tags`: workspace-local normalized labels and same-workspace associations.
- `item_identifiers`: workspace, item, scheme, normalized value. Do not make ISBN/barcodes globally unique.
- `item_media`: workspace, item, private Storage reference, MIME, ordering, creator. Never expose unrestricted public bucket.
- `item_sources`: field-level source kind, source URL/reference and confidence for user input, scanner, external provider or AI.

### Collaboration
- `share_grants`: `source_workspace_id`, `resource_type` item|collection, `item_id` XOR `collection_id`, `recipient_user_id` XOR `recipient_workspace_id`, `permission` read (first release), created_by, expiry/revocation, timestamps. The original owner/source workspace never changes.
- Access to a shared collection includes currently and subsequently linked items (dynamic membership); make that explicit when enabling sharing. Disallow or separately approve collection cross-workspace nested tree semantics.
- Household recipient workspace means any currently active member of that household can view the shared resource. Removing a recipient member revokes their effective access immediately.
- Item-level sharing does not automatically disclose unrelated collections, source household membership, unrelated item metadata, documents or the complete source location tree.
- Share grant read policies never expose owner workspace membership lists or invite tokens.
- Source owner/admin may revoke grants. Creating a grant is a privileged server action that checks active source access and recipient existence, source vs target boundaries, quotas and recipient type.

### AI and audit
- `ai_jobs`: workspace, requester, kind, state, input reference, timestamps, usage accounting, sanitized error.
- `ai_candidates`: job, workspace, structured proposed content with confidence and provenance, expires_at and confirmed_at. Only authorized requester can confirm.
- `audit_events`: actor, workspace, action, target ID, date and carefully minimized JSONB context; privileged writes only, limited reader audience.

## 3. Relationship map
- auth.users 1—1 profiles; auth.users 1—N workspace_members.
- workspaces 1—N workspace_members, workspace_invites, items, collections, templates, locations, tags, AI jobs.
- templates 1—N immutable template_versions; items N—1 chosen template_versions (nullable).
- items N—M collections via collection_items, items N—M tags via item_tags.
- items 1—N media, identifiers, field sources; items N—1 location (nullable).
- share_grants link one item **or** one collection in source workspace to one user **or** one recipient workspace.
- All workspace-scoped child tables carry workspace_id and **composite FKs** referencing parent (workspace_id, id), preventing cross-tenant references even if application logic errs.

## 4. Authorization

| Action | Source owner | Source admin | Source editor | Source viewer | External share recipient |
|---|---|---|---|---|---|
| Read active source items/collections | yes | yes | yes | yes | only granted subset, read only |
| Create/edit content | yes | yes | yes | no | no |
| Move item to trash/restore | yes | yes | yes | no | no |
| Permanently purge item | yes, privileged endpoint | no | no | no | no |
| Invite/manage non-owner membership | yes | yes | no | no | no |
| Create/revoke outward grant | yes | yes | no | no | no |
| Transfer workspace ownership/delete workspace | yes, privileged endpoint | no | no | no | no |
| Workspace-wide export | yes | yes | no | no | no |

Personal workspace has exactly one member (owner). For cross-user or household sharing of personal content, use share_grants—not extra personal workspace members. In source workspace, item reads exclude trash unless the caller is allowed to view trash via a distinct authenticated route. For external recipient, trash is never visible.

**Trust boundary:** RLS gates ordinary reads and writes, immutable identifiers and protected columns are enforced with constraints/triggers or narrow server RPCs. A client-provided `role`, `workspace_id`, `created_by` or `owner_user_id` never confers rights. Keep direct DELETE disabled on user-facing tables. An item's ownership cannot be changed by untrusted direct update.

## 5. Indexing / operations
- PK UUIDs, created_at and updated_at `timestamptz`.
- Unique `(workspace_id, id)` on cross-workspace FK parents.
- Index `items(workspace_id, deleted_at, created_at DESC)`, `collections(workspace_id, deleted_at)`, `collection_items(item_id)`, normalized `item_identifiers(scheme, normalized_value)`, `share_grants` by recipient and active expiry, `workspace_members(user_id)`.
- GIN for items attributes only if real query patterns justify it. Use explicit sanitized filters and indexes for frequent searches; use FTS or trigram as workload requires.
- Workspace-wide exports must be rate-limited and audited.
- A trash purge needs a separate explicit retention rule plus cleanup of Storage objects and dependent records, with back-up/recovery safeguards.
- AI suggestions should be versioned; external provider results can change and may be wrong.

## 6. Proposed SQL and deployment gates
- `docs/sql/curio_v2_schema_proposal.sql` is a **design reference, not a runnable production migration**. It provides relational DDL/selected guardrails but must pass a clean ephemeral Supabase migration test and a RLS adversarial test suite before promotion into `supabase/migrations/`.
- It is important to reconcile current historical Supabase migrations: the repo README and separately supplied connection details refer to different projects. Never run this file on either without independently verifying environment.
- Review RLS WITH CHECK conditions, trigger column protection, SECURITY DEFINER function search_path/grants, Storage policy, invite redemption function and full grant lifecycle before deployment.
- Confirm data retention periods, editor restore behavior on shared content, household grants lifecycle, and how files shared through signed URLs are revoked.
- Rotate privileged secrets that appeared in shared project material; never copy them to docs or code.

## 7. Minimum required integration tests (before release)
1. A and B personal workspaces do not leak data or objects in any table/Storage.
2. B may read only a specifically shared item, not its sibling items or source workspace members.
3. Shared collection grants expose currently linked items and newly added ones; revocation removes access.
4. Household share is limited to current active recipient members; removal immediately denies access.
5. Editor can mark deleted/restore; viewer and external recipients cannot; editor cannot hard delete.
6. A trashed object is absent from ordinary listings and external shares; restoring retains its collection membership.
7. Cross-workspace foreign keys reject associations, parent IDs and location references.
8. Individual item must have quantity=1 piece; quantity-mode item has positive amount and permitted unit; changes remain atomic.
9. No changes to existing confirmed attributes without user confirmation from AI candidate.
10. Invite expiration, replay, scope downgrade, last-owner guard and forged role tests.
11. API and Storage requests by unauthorized users fail, even with guessed IDs.
12. Schema migrations run cleanly and rollback/recovery plans are reviewed.

## 8. Decisions reserved for implementation review
- Whether future external grants support editing: **not in v1**.
- Quantity units and fractional precision, transaction history and split/merge UX.
- Retention duration of trash and audit records, optional legal holds.
- Whether nested collection shares include child collections (initially no, unless explicitly chosen).
- Smart collections and complex cross-workspace duplication are deferred from first implementation.
