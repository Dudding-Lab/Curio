# Konvuela architecture decision 03 — Offline-first private collections, online-only verified catalog

Date: 2026-11-08
Status: approved by product owner. Implementation pending.

## Normative requirements

1. Personal collection creation, editing, viewing, and manual item registration MUST work without network connectivity on Android, iOS and Web (Web offline support requires persistent browser storage and offline application shell).
2. Local durable storage is the authoritative working copy while offline. Writes MUST not depend on Supabase Auth refresh, RPC calls, or model availability. A sync outbox records unsent operations for later authenticated synchronization.
3. The shared Konvuela catalog is stored and operated **online only** in the backend `kovunela_catalog`; an offline client may retain previously received metadata suggestions for display but must not pretend it has a locally synchronized master catalog.
4. The shared catalog may automatically grow only from **user-verified factual object data**. Verification means an explicit user confirmation of factual fields before they become eligible for catalog contribution; an AI suggestion alone or a simple implicit item-save is NOT verification.
5. Only strictly allowlisted non-user-specific catalog fields enter the contribution staging pipeline (such as normalized identifier, title, author, publisher, publication year, language, object type). Never stage personal notes, ownership, user/household IDs as published facts, private photos, item location, personal valuations or free-form text.
6. Catalog contributions should be de-identified before any public/shared fact store. Private linkage for review, idempotence and deletion requests MUST be access-restricted and retention-limited; the internal queue may temporarily refer to a private item only as a security-controlled processing detail.
7. Contributions remain separate from publication: syntactic validation, deduplication, provenance/legal reuse checks, and automated/manual review as appropriate must pass before facts become globally reusable.
8. Offline user verification is locally recorded and queued until authenticated connectivity returns. Duplicate sync retries MUST NOT create duplicate catalog contributions.
9. Offline item edits can be made regardless of whether AI services are accessible. Online AI assistance (image recognition, barcode/ISBN reference lookup, metadata suggestions, categorization) enriches the same editable draft later and MUST require user confirmation before applying uncertain suggestions.
10. Preserve existing local changes across app restart and failed network requests. Define conflict resolution, tombstones/soft delete, per-record revision metadata and data-migration strategy before production launch.
11. Explicitly disclose catalog contribution behavior in the product UX. User consent/confirmation and related deletion/withdrawal expectations require product/legal review; do not treat ordinary save as opt-in verification.

## Intended client workflow

- Offline: local create/update with category, type/template snapshot, metadata, timestamps and local UUID; commit local transaction; append durable outbox operation.
- Online: authenticate; push queued private mutations idempotently; pull only authorized workspace changes; resolve conflicts or flag for review.
- When online: suggest AI or catalog enrichment using server functions; user compares and accepts proposals; save accepted fields locally, sync privately.
- When the user explicitly verifies catalog-eligible factual fields: create a separate pending contribution event; sync to private review queue online; validate, deduplicate and promote only eligible facts.
- When offline again: continue using local personal collections without blocking on server responses.

## Critical gap in currently deployed backend

As inspected on 2026-11-07/08, the `kovunela.items` trigger `enqueue_catalog_contribution` runs automatically on insert and on some updates. `kovunela_catalog.enqueue_item_contribution()` puts items into `contribution_queue` and sets `confirmed_at` in its INSERT/UPSERT flow. This equates an ordinary item save with catalog confirmation. It **does not implement** the approved requirement that catalog-eligible records must first be verified by the user.

**Required before enabling global promotion:** redesign this flow to gate contributions on a distinct verified state/event; prevent accidental implicit confirmation; retain safe background processing for already-verified candidates. Do not silently change live triggers or delete queued records before backup, migration history reconciliation, data-flow review and tests. Until fixed, never describe automatic staging as user-verified.

## API and storage design tasks

- Select an appropriate Flutter local database (e.g. Drift/SQLite for mobile/desktop; supported persistent Web implementation) with transactional outbox.
- Decide encrypted storage for sensitive private metadata and secure session storage; avoid persisting privileged server keys.
- Design local IDs, server IDs, revision vectors/ETags, sync cursor, tombstone lifecycle, backoff and conflict UI.
- Implement local-first repository abstraction. Existing `KonvuelaRepository` currently calls RPC directly and is **online-only**; it must be refactored rather than treated as offline-ready.
- Add offline-capable metadata template snapshots and robust schema versioning; defer any required cloud validation until connectivity returns, without losing the local draft.
- Implement user verification workflow: immutable snapshot of selected factual fields, verification timestamp, per-field evidence/quality status, separate server-side submission endpoint and idempotency key.
- Define privacy controls and retention for staging queue, review candidates, dedup grouping, and accepted catalog facts.
- Test: airplane mode create/edit/restart; reconnect and retry; two-device conflict; different-user data segregation; AI unavailable; unverified item never contributes; verified record contributes at most once; user-specific fields never enter catalog.

## Rollout gates

- No claim of offline operation until physical/emulated device and Web persistence tests pass.
- No automatic catalog promotion until verified contribution gates and privacy tests pass.
- Current GitHub PR #4 remains draft; this document alone is a requirement, not an implementation.
