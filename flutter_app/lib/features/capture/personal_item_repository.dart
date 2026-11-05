import 'package:curio/features/capture/manual_item_draft.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// An explicit contract for server-confirmed item creation.
///
/// The client must never choose created_by or workspace_id: those are derived
/// from the authenticated caller by the reviewed server-side RPC.
abstract interface class PersonalItemRepository {
  Future<String> create(ManualItemDraft draft);
}

/// Prepared for isolated development testing. NOT wired to a Save button.
///
/// Using this against a legacy or production Supabase schema is unsupported.
/// First validate docs/sql/kovunela_phase1_dev_only.sql in a clean DEV project.
class SupabasePersonalItemRepository implements PersonalItemRepository {
  SupabasePersonalItemRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<String> create(ManualItemDraft draft) async {
    final normalized = draft.normalized();
    if (normalized.validate() != null) {
      throw ArgumentError('Invalid item draft');
    }
    final result = await _client.rpc('kv_create_personal_item', params: {
      'p_title': normalized.title,
      'p_description': normalized.description,
    });

    if (result is! String || result.isEmpty) {
      throw StateError('Server did not return a confirmed item ID');
    }
    return result;
  }
}
