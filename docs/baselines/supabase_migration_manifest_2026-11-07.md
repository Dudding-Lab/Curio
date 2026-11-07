# Remote Supabase migration manifest (read-only inventory)

Remote project: `tgawxheqrcqhcvxaexvd`  
Captured: 2026-11-07  
Remote migration records: **32**

> WARNING: This manifest is **not** migration SQL, a restorable backup or authorization to replay any historical migrations. The deployed SQL bodies are not available through `list_migrations`. Reconstruct with an authenticated approved CLI `supabase db pull`/schema dump, inspect the diff, and record the result as a reconciled baseline. Do not invent historical SQL or run existing October migrations against a populated environment.

| Version | Remote migration name |
|---|---|
| `20261106052038` | `kovunela_additive_private_workspace_item_foundation` |
| `20261106060542` | `kovunela_list_private_items` |
| `20261106060553` | `kovunela_private_item_list_wrapper` |
| `20261106062239` | `kovunela_restrict_create_rpc_to_authenticated` |
| `20261106071440` | `kovunela_private_collections_membership_api` |
| `20261106073640` | `kovunela_categories_templates_attributes_foundation` |
| `20261106073653` | `kovunela_template_workspace_scope_guards` |
| `20261106073723` | `kovunela_personal_taxonomy_typed_items_api` |
| `20261106073756` | `kovunela_fix_schema_validation_postgres17` |
| `20261106090158` | `kovunela_global_standard_template_catalog_and_derivation` |
| `20261106090234` | `kovunela_household_template_shares_and_safe_copy` |
| `20261106090721` | `kovunela_guarded_template_copy_and_move_between_owned_workspaces` |
| `20261106090941` | `kovunela_personal_template_field_presentation_and_share_revocation` |
| `20261106091053` | `kovunela_immutable_standard_template_version_snapshots` |
| `20261106095417` | `kovunela_per_field_translation_mode_and_original_text_snapshots` |
| `20261106102348` | `kovunela_validate_required_choice_and_localized_field_presentation` |
| `20261106102656` | `kovunela_enforce_required_and_choice_metadata_in_typed_item_rpc` |
| `20261106112148` | `kovunela_daily_vision_ai_request_limit` |
| `20261106131727` | `kovunela_private_global_curated_catalog_v1` |
| `20261106132320` | `kovunela_catalog_default_block_unattributed_reuse` |
| `20261106160938` | `global_catalog_auto_contributions` |
| `20261106161054` | `connect_kovunela_items_to_catalog_queue` |
| `20261106162354` | `confirmed_catalog_contributions` |
| `20261106162835` | `auto_enqueue_catalog_on_save` |
| `20261106162857` | `disable_separate_catalog_confirmation_rpc` |
| `20261106165807` | `stage_book_candidates_from_saved_items` |
| `20261106165837` | `schedule_kovunela_catalog_staging` |
| `20261107072620` | `catalog_isbn_dedup_review_groups` |
| `20261107112518` | `standard_item_atomic_save` |
| `20261107113027` | `standard_item_rpc_invoker_fix` |
| `20261107113518` | `standard_item_invoker_wrapper` |
| `20261107195644` | `konvuela_restrict_legacy_household_trigger_execution` |

## Controlled recovery / future migration gate

1. Confirm a tested, restorable encrypted backup using the approved Supabase backup process.
2. Export the production **schema only** (including `public`, `kovunela`, `kovunela_catalog`, grants, policies, functions, triggers, cron jobs) into a restricted environment; **do not** export private records to GitHub.
3. Compare resulting schema DDL with this manifest and the metadata snapshot at `docs/baselines/supabase_objects_2026-11-07.json`.
4. Create a clean baseline for NEW environments without pretending it is any of the original historical migrations. Do not `db push` before dry-run and explicit reconciliation.
5. Deploy subsequent changes via reviewed migration files; test rollback/restore in isolation.
