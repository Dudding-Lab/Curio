# Kovunela – persönliche Sammlungen (6 November 2026)

## Deployed
Supabase Curio (`tgawxheqrcqhcvxaexvd`), migration `kovunela_private_collections_membership_api`.

The private `kovunela` schema now contains two new RLS-enabled, non-exposed tables:
- `collections`: belongs to one workspace, unique ID, title and optional description, created_by, soft-delete marker.
- `collection_items`: many-to-many assignment of items to collections; the same item can belong to several collections, and to none.

Existing `kovunela.items` has no mandatory collection reference; capture remains independent of organization.

Authenticated API functions (public SECURITY INVOKER wrappers, internally checked SECURITY DEFINER logic):
- `kv_create_personal_collection(p_title,p_description)`
- `kv_list_personal_collections()`
- `kv_add_personal_item_to_collection(p_item_id,p_collection_id)`

All writes derive the personal workspace from server-side `auth.uid()`, never a client-supplied workspace ID. Assignment checks that the item **and** collection belong to the caller's personal workspace and are not soft-deleted. Re-adding the same item is safe (`ON CONFLICT DO NOTHING`). Personal collection list is capped at 100 until cursor pagination is implemented.

### Verified
Supabase returned the new tables with RLS enabled and zero rows; migration appears in history.
Role privilege query:
- `anon`: no execute access to any new public RPC, no direct insert into `kovunela.collection_items`.
- `authenticated`: execution access to the three RPCs; still no direct insert into `kovunela.collection_items`.

### Flutter
- Added typed `PersonalCollectionRepository` (list/create/assign).
- Added read-only `PersonalCollectionsScreen` at `/collections/personal`, separately accessible from home.
- New localized strings in all seven ARB locales.
- Added fake-repository tests; real Auth isolation test now includes cross-workspace attachment rejection and collection isolation.

### Pending
- The real two-session Auth integration test cannot run until test e-mail forwarding and confirmed accounts are available. It skips in ordinary CI; a green CI run is **not** proof of real user isolation.
- UI creation and assignment actions are intentionally not exposed pending that authorization test.
- The legacy `public.collections` and legacy household tables are left intact for now; they are **not** the same objects as these new tables.
- Full smart collections, hierarchies, collection filters and shared-household roles remain future work.
