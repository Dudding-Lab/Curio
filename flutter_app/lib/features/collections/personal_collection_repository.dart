import 'package:supabase_flutter/supabase_flutter.dart';

class PersonalCollection {
  const PersonalCollection({
    required this.id,
    required this.title,
    required this.description,
    required this.createdAt,
  });

  final String id;
  final String title;
  final String description;
  final DateTime createdAt;

  factory PersonalCollection.fromJson(Map<String, dynamic> json) =>
      PersonalCollection(
        id: json['id'] as String,
        title: json['title'] as String,
        description: json['description'] as String? ?? '',
        createdAt: DateTime.parse(json['created_at'] as String),
      );
}

abstract interface class PersonalCollectionRepository {
  Future<List<PersonalCollection>> list();
  Future<String> create({required String title, String description = ''});
  Future<void> addItem({
    required String itemId,
    required String collectionId,
  });
}

/// Calls the authenticated RPCs; never accepts a client-supplied workspace ID.
/// Writing methods remain unused in the UI pending real two-user Auth tests.
class SupabasePersonalCollectionRepository
    implements PersonalCollectionRepository {
  SupabasePersonalCollectionRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<List<PersonalCollection>> list() async {
    final result = await _client.rpc('kv_list_personal_collections');
    if (result is! List) {
      throw StateError('Expected a list of collections');
    }
    return result
        .map((row) => PersonalCollection.fromJson(
              Map<String, dynamic>.from(row as Map),
            ))
        .toList(growable: false);
  }

  @override
  Future<String> create({
    required String title,
    String description = '',
  }) async {
    final normalizedTitle = title.trim();
    final normalizedDescription = description.trim();
    if (normalizedTitle.isEmpty ||
        normalizedTitle.length > 200 ||
        normalizedDescription.length > 5000) {
      throw ArgumentError('Invalid collection details');
    }
    final result = await _client.rpc('kv_create_personal_collection', params: {
      'p_title': normalizedTitle,
      'p_description': normalizedDescription,
    });
    if (result is! String || result.isEmpty) {
      throw StateError('Server did not confirm collection creation');
    }
    return result;
  }

  @override
  Future<void> addItem({
    required String itemId,
    required String collectionId,
  }) async {
    final result =
        await _client.rpc('kv_add_personal_item_to_collection', params: {
      'p_item_id': itemId,
      'p_collection_id': collectionId,
    });
    if (result != true) {
      throw StateError('Server did not confirm collection assignment');
    }
  }
}
