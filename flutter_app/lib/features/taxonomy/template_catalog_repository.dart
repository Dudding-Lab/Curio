import 'package:supabase_flutter/supabase_flutter.dart';

/// An official read-only catalog entry, independent of any user's workspace.
class StandardObjectTemplate {
  const StandardObjectTemplate({
    required this.id,
    required this.code,
    required this.title,
    required this.categoryCode,
    required this.version,
    required this.fields,
  });

  final String id;
  final String code;
  final String title;
  final String categoryCode;
  final int version;
  final Map<String, String> fields;

  factory StandardObjectTemplate.fromJson(Map<String, dynamic> json) =>
      StandardObjectTemplate(
        id: json['id'] as String,
        code: json['code'] as String,
        title: json['title'] as String,
        categoryCode: json['category_code'] as String,
        version: json['version'] as int,
        fields: (json['field_schema'] as Map<String, dynamic>)
            .map((key, value) => MapEntry(key, value as String)),
      );
}

class SharedObjectTemplate {
  const SharedObjectTemplate({
    required this.templateId,
    required this.title,
    required this.versionId,
    required this.fields,
  });

  final String templateId;
  final String title;
  final String versionId;
  final Map<String, String> fields;

  factory SharedObjectTemplate.fromJson(Map<String, dynamic> json) =>
      SharedObjectTemplate(
        templateId: json['template_id'] as String,
        title: json['title'] as String,
        versionId: json['version_id'] as String,
        fields: (json['field_schema'] as Map<String, dynamic>)
            .map((key, value) => MapEntry(key, value as String)),
      );
}

abstract interface class TemplateCatalogRepository {
  Future<List<StandardObjectTemplate>> listStandards();
  Future<String> deriveStandard({
    required String standardId,
    String? title,
    Map<String, String> addedFields = const {},
  });
  Future<void> sharePersonalTemplate({
    required String templateId,
    required String householdWorkspaceId,
  });
  Future<List<SharedObjectTemplate>> listSharedForWorkspace(String workspaceId);
  Future<String> copySharedIntoWorkspace({
    required String templateId,
    required String householdWorkspaceId,
  });
  Future<String> copyOwnedToWorkspace({
    required String templateId,
    required String targetWorkspaceId,
  });
  Future<String> moveOwnedToWorkspace({
    required String templateId,
    required String targetWorkspaceId,
  });
  Future<void> configurePersonalTemplate({
    required String templateId,
    required Map<String, Map<String, dynamic>> fieldPresentation,
  });
  Future<Map<String, dynamic>?> getPersonalTemplatePresentation(String templateId);
  Future<bool> revokePersonalShare({
    required String templateId,
    required String householdWorkspaceId,
  });
}

/// Reads are safe to use in the UI. Writes remain unexposed until verified
/// by actual separate Auth sessions (including household membership).
class SupabaseTemplateCatalogRepository implements TemplateCatalogRepository {
  SupabaseTemplateCatalogRepository(this._client);

  final SupabaseClient _client;
  static final _keyPattern = RegExp(r'^[a-z][a-z0-9_]{0,63}$');
  static const _supportedTypes = {'text', 'number', 'boolean', 'date'};

  @override
  Future<List<StandardObjectTemplate>> listStandards() async {
    final result = await _client.rpc('kv_list_standard_templates');
    if (result is! List) throw StateError('Invalid standard catalog response');
    return result
        .map((row) => StandardObjectTemplate.fromJson(
              Map<String, dynamic>.from(row as Map),
            ))
        .toList(growable: false);
  }

  @override
  Future<String> deriveStandard({
    required String standardId,
    String? title,
    Map<String, String> addedFields = const {},
  }) async {
    if ((title != null && title.trim().length > 120) ||
        addedFields.length > 30 ||
        addedFields.entries.any((entry) =>
            !_keyPattern.hasMatch(entry.key) ||
            !_supportedTypes.contains(entry.value))) {
      throw ArgumentError('Invalid template extension');
    }
    final id = await _client.rpc('kv_derive_standard_template', params: {
      'p_standard_id': standardId,
      'p_title': title?.trim(),
      'p_added_fields': addedFields,
    });
    if (id is! String || id.isEmpty) {
      throw StateError('Template derivation not confirmed');
    }
    return id;
  }

  @override
  Future<void> sharePersonalTemplate({
    required String templateId,
    required String householdWorkspaceId,
  }) async {
    final result = await _client.rpc('kv_share_personal_template', params: {
      'p_template_id': templateId,
      'p_target_workspace_id': householdWorkspaceId,
    });
    if (result != true) throw StateError('Template share not confirmed');
  }

  @override
  Future<List<SharedObjectTemplate>> listSharedForWorkspace(
    String workspaceId,
  ) async {
    final result = await _client.rpc('kv_list_shared_templates', params: {
      'p_workspace_id': workspaceId,
    });
    if (result is! List) throw StateError('Invalid shared catalog response');
    return result
        .map((row) => SharedObjectTemplate.fromJson(
              Map<String, dynamic>.from(row as Map),
            ))
        .toList(growable: false);
  }

  @override
  Future<Map<String, dynamic>?> getPersonalTemplatePresentation(
    String templateId,
  ) async {
    final result = await _client.rpc('kv_get_personal_template_presentation',
        params: {'p_template_id': templateId});
    if (result == null) return null;
    if (result is! Map) throw StateError('Invalid field presentation');
    return Map<String, dynamic>.from(result);
  }

  @override
  Future<void> configurePersonalTemplate({
    required String templateId,
    required Map<String, Map<String, dynamic>> fieldPresentation,
  }) async {
    final result = await _client.rpc('kv_configure_personal_template', params: {
      'p_template_id': templateId,
      'p_presentation': fieldPresentation,
    });
    if (result != true) throw StateError('Field presentation not confirmed');
  }

  @override
  Future<bool> revokePersonalShare({
    required String templateId,
    required String householdWorkspaceId,
  }) async {
    final result = await _client.rpc('kv_revoke_personal_template_share',
        params: {
          'p_template_id': templateId,
          'p_target_workspace_id': householdWorkspaceId,
        });
    if (result is! bool) throw StateError('Share revocation not confirmed');
    return result;
  }

  @override
  Future<String> copyOwnedToWorkspace({
    required String templateId,
    required String targetWorkspaceId,
  }) async {
    final id = await _client.rpc('kv_copy_owned_template', params: {
      'p_template_id': templateId,
      'p_target_workspace_id': targetWorkspaceId,
    });
    if (id is! String || id.isEmpty) {
      throw StateError('Template copy not confirmed');
    }
    return id;
  }

  @override
  Future<String> moveOwnedToWorkspace({
    required String templateId,
    required String targetWorkspaceId,
  }) async {
    final id = await _client.rpc('kv_move_owned_template', params: {
      'p_template_id': templateId,
      'p_target_workspace_id': targetWorkspaceId,
    });
    if (id is! String || id.isEmpty) {
      throw StateError('Template move not confirmed');
    }
    return id;
  }

  @override
  Future<String> copySharedIntoWorkspace({
    required String templateId,
    required String householdWorkspaceId,
  }) async {
    final id = await _client.rpc('kv_copy_shared_template', params: {
      'p_template_id': templateId,
      'p_target_workspace_id': householdWorkspaceId,
    });
    if (id is! String || id.isEmpty) {
      throw StateError('Template copy not confirmed');
    }
    return id;
  }
}
