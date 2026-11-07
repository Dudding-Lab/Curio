import 'package:curio/features/taxonomy/template_catalog_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// The server chooses the authenticated workspace and reuses the user's
/// derived standard version. The client never sends a workspace or user ID.
abstract interface class StandardItemCaptureRepository {
  Future<List<StandardObjectTemplate>> listStandards();
  Future<String> create({
    required String standardCode,
    required String title,
    required String description,
    required Map<String, dynamic> attributes,
  });
}

class SupabaseStandardItemCaptureRepository
    implements StandardItemCaptureRepository {
  SupabaseStandardItemCaptureRepository(this._client);
  final SupabaseClient _client;

  @override
  Future<List<StandardObjectTemplate>> listStandards() async =>
      SupabaseTemplateCatalogRepository(_client).listStandards();

  @override
  Future<String> create({
    required String standardCode,
    required String title,
    required String description,
    required Map<String, dynamic> attributes,
  }) async {
    if (title.trim().isEmpty || title.trim().length > 200 ||
        description.trim().length > 5000) {
      throw ArgumentError('Invalid item');
    }
    final result = await _client.rpc('kv_create_standard_personal_item', params: {
      'p_standard_code': standardCode,
      'p_title': title.trim(),
      'p_description': description.trim(),
      'p_attributes': attributes,
    });
    if (result is! String || result.isEmpty) {
      throw StateError('Server did not confirm saved item');
    }
    return result;
  }
}
