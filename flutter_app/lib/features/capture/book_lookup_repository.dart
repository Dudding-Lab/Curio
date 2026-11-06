import 'package:curio/features/capture/capture_suggestion.dart';
import 'package:curio/features/capture/canonical_catalog_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class GoogleBookCandidate {
  const GoogleBookCandidate({
    required this.title,
    required this.sourceId,
    required this.attributes,
    this.source = 'google_books',
  });

  final String title;
  final String sourceId;
  final String source;
  final Map<String, dynamic> attributes;

  factory GoogleBookCandidate.fromJson(Map<String, dynamic> json) {
    if (json['source'] != 'google_books' ||
        json['title'] is! String ||
        json['source_id'] is! String ||
        json['attributes'] is! Map) {
      throw const FormatException('Unexpected book candidate');
    }
    return GoogleBookCandidate(
      title: json['title'] as String,
      sourceId: json['source_id'] as String,
      attributes: Map<String, dynamic>.from(json['attributes'] as Map),
      source: 'google_books',
    );
  }

  CaptureSuggestion toSuggestion() => CaptureSuggestion(
        templateCode: 'book',
        title: title,
        attributes: attributes,
        evidence: {'isbn': source == 'kovunela_catalog'
            ? 'Kovunela catalog: reviewed metadata' : 'Google Books: exact ISBN match'},
      );
}

abstract interface class BookLookupRepository {
  Future<List<GoogleBookCandidate>> byIsbn(String isbn);
}

/// Calls only the server endpoint; no API keys are stored in Flutter.
class SupabaseBookLookupRepository implements BookLookupRepository {
  SupabaseBookLookupRepository(this._client);
  final SupabaseClient _client;

  @override
  Future<List<GoogleBookCandidate>> byIsbn(String isbn) async {
    final response = await _client.functions.invoke(
      'kovunela-books-lookup',
      body: {'isbn': isbn},
    );
    final payload = response.data;
    if (response.status != 200 || payload is! Map ||
        payload['books'] is! List) {
      throw StateError('Book lookup was unsuccessful');
    }
    return (payload['books'] as List)
        .map((item) => GoogleBookCandidate.fromJson(
              Map<String, dynamic>.from(item as Map),
            ))
        .toList(growable: false);
  }
}

 
/// Search the curated catalog before requesting data from the external
/// provider. A catalog miss is different from an RPC error: on failure the
/// fallback is intentionally blocked to avoid unexpected third-party calls.
class CatalogFirstBookLookupRepository implements BookLookupRepository {
  CatalogFirstBookLookupRepository({
    required CanonicalCatalogRepository catalog,
    required BookLookupRepository external,
  }) : _catalog = catalog, _external = external;

  final CanonicalCatalogRepository _catalog;
  final BookLookupRepository _external;

  @override
  Future<List<GoogleBookCandidate>> byIsbn(String isbn) async {
    final normalized = CatalogIdentifier.normalize(isbn);
    final type = normalized.length == 10 ? 'isbn10' : 'isbn13';
    if (!CatalogIdentifier.valid(type, normalized)) {
      throw const FormatException('Invalid ISBN check digit');
    }
    final hit = await _catalog.lookup(
      identifierType: type,
      identifier: normalized,
    );
    if (hit != null && hit.objectType == 'book' &&
        hit.identifier == normalized && hit.identifierType == type) {
      return [
        GoogleBookCandidate(
          title: hit.title,
          sourceId: hit.id,
          source: 'kovunela_catalog',
          attributes: {...hit.attributes, 'isbn': normalized},
        ),
      ];
    }
    // Catalog is empty or has an unrelated object: external lookup is
    // permitted, but these responses are not automatically cached/shared.
    return _external.byIsbn(normalized);
  }
}
