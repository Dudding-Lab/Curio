import 'package:supabase_flutter/supabase_flutter.dart';

/// Publicly reusable metadata only. Never accepts private collection payloads.
class CanonicalCatalogHit {
  const CanonicalCatalogHit({
    required this.id,
    required this.objectType,
    required this.title,
    required this.attributes,
    required this.identifier,
    required this.identifierType,
  });

  final String id;
  final String objectType;
  final String title;
  final String identifier;
  final String identifierType;
  final Map<String, dynamic> attributes;

  factory CanonicalCatalogHit.fromJson(Map<String, dynamic> json) {
    if (json['source'] != 'kovunela_catalog' ||
        json['requires_review'] != true ||
        json['catalog_id'] is! String ||
        json['object_type'] is! String ||
        json['title'] is! String ||
        json['identifier'] is! String ||
        json['identifier_type'] is! String ||
        json['attributes'] is! Map) {
      throw const FormatException('Invalid canonical catalog response');
    }
    final title = (json['title'] as String).trim();
    if (title.isEmpty || title.length > 200) {
      throw const FormatException('Invalid catalog title');
    }
    final attrs = Map<String, dynamic>.from(json['attributes'] as Map);
    if (attrs.length > 30) {
      throw const FormatException('Excessive catalog attributes');
    }
    // A defense-in-depth allowlist independent of the backend's schema.
    const allowedFields = {
      'author','publisher','publication_year','language','manufacturer',
      'model','brand','description','isbn',
    };
    if (attrs.keys.any((key) => !allowedFields.contains(key)) ||
        attrs.values.any((value) => value is! String && value is! num &&
            value is! bool)) {
      throw const FormatException('Unexpected personal or untyped catalog data');
    }
    return CanonicalCatalogHit(
      id: json['catalog_id'] as String,
      objectType: json['object_type'] as String,
      title: title,
      attributes: attrs,
      identifier: json['identifier'] as String,
      identifierType: json['identifier_type'] as String,
    );
  }
}

abstract interface class CanonicalCatalogRepository {
  Future<CanonicalCatalogHit?> lookup({
    required String identifierType,
    required String identifier,
  });
}

class SupabaseCanonicalCatalogRepository implements CanonicalCatalogRepository {
  SupabaseCanonicalCatalogRepository(this._client);
  final SupabaseClient _client;

  @override
  Future<CanonicalCatalogHit?> lookup({
    required String identifierType,
    required String identifier,
  }) async {
    final response = await _client.rpc('kv_catalog_lookup', params: {
      'p_identifier_type': identifierType,
      'p_identifier': identifier,
    });
    if (response == null) return null;
    if (response is! Map) throw const FormatException('Unexpected catalog result');
    return CanonicalCatalogHit.fromJson(
      Map<String, dynamic>.from(response),
    );
  }
}

/// ISBN-10/13 and EAN-13/GTIN-14 checksum verification, no network required.
/// Never allow OCR garbage to trigger a paid external lookup.
class CatalogIdentifier {
  static String normalize(String value) =>
      value.replaceAll(RegExp(r'[\\s-]'), '').toUpperCase();

  static bool valid(String type, String value) {
    final code = normalize(value);
    if (type == 'isbn10') {
      if (code.length != 10) return false;
      var sum = 0;
      for (var i = 0; i < 10; i++) {
        final unit = code.codeUnitAt(i);
        final digit = unit == 88 && i == 9 ? 10 : unit - 48;
        if (digit < 0 || digit > 9 && !(i == 9 && digit == 10)) {
          return false;
        }
        sum += (10 - i) * digit;
      }
      return sum % 11 == 0;
    }
    final size = switch (type) {
      'isbn13' || 'ean13' => 13,
      'gtin14' => 14,
      _ => 0,
    };
    if (size == 0 || code.length != size) return false;
    var sum = 0;
    for (var i = 0; i < code.length; i++) {
      final digit = code.codeUnitAt(i) - 48;
      if (digit < 0 || digit > 9) return false;
      sum += digit * ((code.length - i).isEven ? 3 : 1);
    }
    return sum % 10 == 0;
  }
}
