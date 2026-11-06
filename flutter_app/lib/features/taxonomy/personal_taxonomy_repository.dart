import 'package:supabase_flutter/supabase_flutter.dart';

/// A taxonomy category is not a collection or an object type.
class PersonalCategory {
  const PersonalCategory({
    required this.id,
    required this.code,
    required this.label,
  });

  final String id;
  final String code;
  final String label;

  factory PersonalCategory.fromJson(Map<String, dynamic> json) =>
      PersonalCategory(
        id: json['id'] as String,
        code: json['code'] as String,
        label: json['label'] as String,
      );
}

/// Versioned attribute definitions. Keys are stable machine-readable codes,
/// e.g. 'manufacturer' -> 'text', 'purchase_year' -> 'number'.
class PersonalObjectType {
  const PersonalObjectType({
    required this.id,
    required this.title,
    required this.templateVersionId,
    required this.fields,
  });

  final String id;
  final String title;
  final String templateVersionId;
  final Map<String, String> fields;

  factory PersonalObjectType.fromJson(Map<String, dynamic> json) =>
      PersonalObjectType(
        id: json['id'] as String,
        title: json['title'] as String,
        templateVersionId: json['template_version_id'] as String,
        fields: (json['field_schema'] as Map<String, dynamic>)
            .map((key, value) => MapEntry(key, value as String)),
      );
}

abstract interface class PersonalTaxonomyRepository {
  Future<List<PersonalCategory>> listCategories();
  Future<List<PersonalObjectType>> listObjectTypes();
  Future<String> createCategory({required String code, required String label});
  Future<String> createObjectType({
    required String title,
    required Map<String, String> fields,
  });
  Future<String> createTypedItem({
    required String title,
    String description = '',
    String? categoryId,
    String? templateVersionId,
    Map<String, dynamic> attributes = const {},
  });
}

/// Server derives user and workspace for every write; no workspace IDs from UI.
/// Mutation methods are NOT connected to UI until Auth isolation is verified.
class SupabasePersonalTaxonomyRepository implements PersonalTaxonomyRepository {
  SupabasePersonalTaxonomyRepository(this._client);
  final SupabaseClient _client;

  @override
  Future<List<PersonalCategory>> listCategories() async {
    final result = await _client.rpc('kv_list_personal_categories');
    if (result is! List) throw StateError('Invalid categories response');
    return result.map((row) => PersonalCategory.fromJson(
      Map<String, dynamic>.from(row as Map),
    )).toList(growable: false);
  }

  @override
  Future<List<PersonalObjectType>> listObjectTypes() async {
    final result = await _client.rpc('kv_list_personal_object_types');
    if (result is! List) throw StateError('Invalid object types response');
    return result.map((row) => PersonalObjectType.fromJson(
      Map<String, dynamic>.from(row as Map),
    )).toList(growable: false);
  }

  @override
  Future<String> createTypedItem({
    required String title,
    String description = '',
    String? categoryId,
    String? templateVersionId,
    Map<String, dynamic> attributes = const {},
  }) async {
    if (title.trim().isEmpty || title.trim().length > 200 ||
        description.trim().length > 5000 ||
        (templateVersionId == null && attributes.isNotEmpty)) {
      throw ArgumentError('Invalid typed item');
    }
    final id = await _client.rpc('kv_create_typed_personal_item', params: {
      'p_title': title.trim(),
      'p_description': description.trim(),
      'p_category_id': categoryId,
      'p_template_version_id': templateVersionId,
      'p_attributes': attributes,
    });
    if (id is! String || id.isEmpty) {
      throw StateError('Item not confirmed');
    }
    return id;
  }

  @override
  Future<String> createCategory({
    required String code,
    required String label,
  }) async {
    if (!RegExp(r'^[a-z][a-z0-9_]{0,63}$').hasMatch(code) ||
        label.trim().isEmpty || label.trim().length > 120) {
      throw ArgumentError('Invalid category');
    }
    final id = await _client.rpc('kv_create_personal_category', params: {
      'p_code': code,
      'p_label': label.trim(),
    });
    if (id is! String || id.isEmpty) {
      throw StateError('Category not confirmed');
    }
    return id;
  }

  @override
  Future<String> createObjectType({
    required String title,
    required Map<String, String> fields,
  }) async {
    if (title.trim().isEmpty || title.trim().length > 120 ||
        fields.length > 30 ||
        fields.entries.any((entry) =>
          !RegExp(r'^[a-z][a-z0-9_]{0,63}$').hasMatch(entry.key) ||
          !const {'text', 'number', 'boolean', 'date'}.contains(entry.value))) {
      throw ArgumentError('Invalid object type');
    }
    final id = await _client.rpc('kv_create_personal_object_type', params: {
      'p_title': title.trim(),
      'p_fields': fields,
    });
    if (id is! String || id.isEmpty) {
      throw StateError('Object type not confirmed');
    }
    return id;
  }
}
