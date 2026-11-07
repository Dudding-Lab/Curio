import 'package:supabase_flutter/supabase_flutter.dart';

/// API boundary for the private Konvuela data model.
///
/// Never access tables in the private `kovunela` or `kovunela_catalog`
/// schemas from the client. Public `kv_*` RPC functions perform authorization.
class KonvuelaRepository {
  KonvuelaRepository(this._client);
  final SupabaseClient _client;

  Future<List<Map<String, dynamic>>> _list(String rpcName) async {
    final result = await _client.rpc(rpcName);
    if (result is! List) {
      throw StateError('Unexpected response from $rpcName');
    }
    return result.map((row) => Map<String, dynamic>.from(row as Map)).toList();
  }

  Future<List<Map<String, dynamic>>> listCollections() =>
      _list('kv_list_personal_collections');

  Future<List<Map<String, dynamic>>> listItems() =>
      _list('kv_list_personal_items');

  Future<List<Map<String, dynamic>>> listStandardTemplates() =>
      _list('kv_list_standard_templates');

  Future<String> createCollection(String title, {String description = ''}) async {
    final cleaned = title.trim();
    if (cleaned.isEmpty || cleaned.length > 200) {
      throw ArgumentError.value(title, 'title', 'Enter a collection title (1-200 characters)');
    }
    final response = await _client.rpc('kv_create_personal_collection', params: {
      'p_title': cleaned,
      'p_description': description,
    });
    if (response is! String || response.isEmpty) {
      throw StateError('Unexpected collection creation response');
    }
    return response;
  }

  Future<String> createItem(String title, {String description = ''}) async {
    final cleaned = title.trim();
    if (cleaned.isEmpty || cleaned.length > 200) {
      throw ArgumentError.value(title, 'title', 'Enter an item title (1-200 characters)');
    }
    final response = await _client.rpc('kv_create_personal_item', params: {
      'p_title': cleaned,
      'p_description': description,
    });
    if (response is! String || response.isEmpty) {
      throw StateError('Unexpected item creation response');
    }
    return response;
  }
}
