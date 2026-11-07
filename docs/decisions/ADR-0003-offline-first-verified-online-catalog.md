# Konvuela architecture decision 03 — Offline-first private collections, online-only verified catalog

Date: 2026-11-08
Status: approved by product owner. Implementation pending.

## Normative requirements

1. Personal collection creation, editing, viewing, and manual item registration MUST work without network connectivity on Android, iOS and Web (Web offline support requires persistent browser storage and offline application shell).
2. Local durable storage is the authoritative working copy while offline. Writes MUST not depend on Supabase Auth refresh, RPC calls, or model availability. A sync outbox records unsent operations for later authenticated synchronization.
3. The shared Konvuela catalog is stored and operated **online only** in the backend `kovunela_catalog`; an offline client may retain previously received metadata suggestions for display but must not pretend it has a locally synchronized master catalog.
4. The shared catalog may automatically grow only from **user-verified factual object data**. Verification occurs when the user saves an item draft containing proposed factual metadata: the save action confirms the fields as seen (including any user edits). AI suggestions alone, background autosaves, temporary draft persistence, and server-side synchronization retries are NOT verification. A purely manual item save also represents user-confirmed factual fields if the user intentionally saves them.
5. Only strictly allowlisted non-user-specific catalog fields enter the contribution staging pipeline (such as normalized identifier, title, author, publisher, publication year, language, object type). Never stage personal notes, ownership, user/household IDs as published facts, private photos, item location, personal valuations or free-form text.
6. Catalog contributions should be de-identified before any public/shared fact store. Private linkage for review, idempotence and deletion requests MUST be access-restricted and retention-limited; the internal queue may temporarily refer to a private item only as a security-controlled processing detail.
7. Contributions remain separate from publication: syntactic validation, deduplication, provenance/legal reuse checks, and automated/manual review as appropriate must pass before facts become globally reusable.
8. Offline user verification is locally recorded and queued until authenticated connectivity returns. Duplicate sync retries MUST NOT create duplicate catalog contributions.
9. Offline item edits can be made regardless of whether AI services are accessible. Online AI assistance (image recognition, barcode/ISBN reference lookup, metadata suggestions, categorization) enriches the same editable draft later and MUST require user confirmation before applying uncertain suggestions.
10. Preserve existing local changes across app restart and failed network requests. Define conflict resolution, tombstones/soft delete, per-record revision metadata and data-migration strategy before production launch.
11. Explicitly explain in the product UX that saving accepted factual metadata verifies it and makes allowed non-personal facts eligible for catalog processing. Review the data protection legal basis, deletion/withdrawal expectations and transparency; save verification is not a substitute for a legally necessary opt-in when one is required.

## Intended client workflow

- Offline: local create/update with category, type/template snapshot, metadata, timestamps and local UUID; commit local transaction; append durable outbox operation.
- Online: authenticate; push queued private mutations idempotently; pull only authorized workspace changes; resolve conflicts or flag for review.
- When online and an identifier is available: query the online Konvuela catalog FIRST. Only a confirmed no-match starts an external web/metadata-provider lookup; if a catalog service fails or is unreachable, report the error or offer an explicitly chosen fallback rather than silently treating it as no match. For identifiers absent from the catalog and with no internet, manual entry stays immediately available.
- Present source-tagged catalog/external/AI metadata as an editable draft. Pressing Save confirms all visible accepted factual data (including user edits), with no separate verification button. The save must atomically capture the verified field snapshot and persist the private item locally, then queue authorized synchronization and a separate eligible-facts contribution event.
- After the user presses Save, automatically queue a pending catalog contribution event for allowlisted, non-user-specific verified facts. Sync the event online with an idempotency key; validate, deduplicate, review legal reuse and provenance, and promote eligible facts. No additional confirmation interaction is required.
- When offline again: continue using local personal collections without blocking on server responses.

## Critical gap in currently deployed backend

As inspected on 2026-11-07/08, the `kovunela.items` trigger `enqueue_catalog_contribution` runs automatically on insert and on some updates. `kovunela_catalog.enqueue_item_contribution()` puts items into `contribution_queue` and sets `confirmed_at` in its INSERT/UPSERT flow. This equates EVERY database-side item INSERT/UPDATE with user confirmation. It **does not distinguish** a user-initiated Save of accepted factual data from a background sync, temporary save, or server-driven update. It also marks records as confirmed without a verified field snapshot.

**Required before enabling global promotion:** redesign this flow to gate contributions on an explicit user Save event, which verifies all accepted factual fields without a separate dialog; prevent implicit confirmation on background writes; retain safe background processing for already-verified candidates. Do not silently change live triggers or delete queued records before backup, migration history reconciliation, data-flow review and tests. Until fixed, never describe automatic staging as user-verified.

## API and storage design tasks

- Select an appropriate Flutter local database (e.g. Drift/SQLite for mobile/desktop; supported persistent Web implementation) with transactional outbox.
- Decide encrypted storage for sensitive private metadata and secure session storage; avoid persisting privileged server keys.
- Design local IDs, server IDs, revision vectors/ETags, sync cursor, tombstone lifecycle, backoff and conflict UI.
- Implement local-first repository abstraction. Existing `KonvuelaRepository` currently calls RPC directly and is **online-only**; it must be refactored rather than treated as offline-ready.
- Add offline-capable metadata template snapshots and robust schema versioning; defer any required cloud validation until connectivity returns, without losing the local draft.
- Implement Save-as-verification workflow: immutable snapshot of accepted factual fields, verification timestamp, provenance/quality status, server-side contribution event and idempotency key; no separate verification button.
- Define privacy controls and retention for staging queue, review candidates, dedup grouping, and accepted catalog facts.
- Test: airplane mode create/edit/restart; reconnect and retry; two-device conflict; different-user data segregation; AI unavailable; unsaved proposal never contributes; background autosave never verifies; explicit Save marks accepted facts verified and queues at most one contribution per revision; user-specific fields never enter catalog; catalog lookup is always first and external lookup only on definitive no-match.

## Rollout gates

- No claim of offline operation until physical/emulated device and Web persistence tests pass.
- No automatic catalog promotion until verified contribution gates and privacy tests pass.
- Current GitHub PR #4 remains draft; this document alone is a requirement, not an implementation.

## Superseding product clarification — 2026-11-08

**Decision:** Save = verification. When a user deliberately saves accepted metadata suggestions (after optionally correcting them), that action verifies the factual data. Automatic online catalog contribution is then eligible, but only for allowlisted non-user-specific facts and subject to backend quality/legal controls. No extra verification button is required. Private item sync and shared fact promotion are separate processes.

**Lookup order:** online Konvuela catalog → external web/provider search ONLY on definitive no-match → optionally AI vision or manual completion. Offline manual entry must always remain possible. Network failure must not be misreported as catalog absence; the user may explicitly choose an external fallback or continue manually.
