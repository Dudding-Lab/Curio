# Kovunela home screen – first implementation

Status: feature branch only; no production deployment.

## User experience
- After successful login, route to `/home` instead of directly to household list.
- Responsive layout with compact bottom navigation and wider navigation rail.
- Localized welcome, capture methods and link to existing household management.
- Capture actions (camera, barcode, manual entry) explicitly notify users that capturing is not yet available. No camera permission, barcode SDK, AI call or item creation is implied.
- Private-space and collection item aggregation are NOT implemented; no invented collection counts appear.
- Existing households and collections routes are retained; do not change Supabase data yet.
- Language picker remains visible on home and login.

## Pending acceptance criteria
- Flutter CI must pass dependency resolution, code generation, static analysis and widget tests.
- Normalize tracked Dart source formatting and restore a strict check before merge (CI temporarily formats sources on runner to expose other failures).
- Implement actual capture/review/save vertical slice before enabling capture actions.
- Add authenticated private workspaces and real collection summaries using reviewed RLS and migrations.
- Test accessibility, narrow displays, text scale and all six locales; translation strings are preliminary drafts.

## Security
Do not ship API keys or secrets in Flutter clients. Any image recognition/model API calls must be mediated by authenticated Supabase Edge Functions and access-controlled storage.
