import 'package:curio/features/capture/manual_item_draft.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// An explicit contract for server-confirmed item creation.
///
/// The client must never choose created_by or workspace_id: those are derived
/// from the authenticated caller by the reviewed server-side RPC.
class PersonalItem {
  const PersonalItem({
    required this.id,
    required this.title,
    required this.description,
    required this.createdAt,
  });

  final String id;
  final String title;
  final String description;
  final DateTime createdAt;

  factory PersonalItem.fromJson(Map<String, dynamic> json) => PersonalItem(
        id: json['id'] as String,
        title: json['title'] as String,
        description: json['description'] as String? ?? '',
        createdAt: DateTime.parse(json['created_at'] as String),
      );
}

abstract interface class PersonalItemRepository {
  Future<String> create(ManualItemDraft draft);
  Future<List<PersonalItem>> list();
}

/// Create is not wired to Save until real cross-user JWT tests pass.
/// Listing is connected to the already deployed authenticated RPC.
class SupabasePersonalItemRepository implements PersonalItemRepository {
  SupabasePersonalItemRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<List<PersonalItem>> list() async {
    final data = await _client.rpc('kv_list_personal_items');
    if (data is! List) {
      throw StateError('Server did not return an item list');
    }
    return data
        .map((row) => PersonalItem.fromJson(Map<String, dynamic>.from(row as Map)))
        .toList(growable: false);
  }

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
