import 'package:supabase_flutter/supabase_flutter.dart';

/// A catalog-first lookup suggestion; saving the accepted fields verifies them.
class BookLookupSuggestion {
  const BookLookupSuggestion({
    required this.source,
    required this.title,
    required this.attributes,
  });

  final String source;
  final String title;
  final Map<String, dynamic> attributes;
}

/// Online lookup by ISBN. The global Konvuela catalog is always queried first.
///
/// An authoritative null result means "no approved catalog entry" and permits
/// an external Google Books fallback. Errors do NOT count as absence.
class CatalogFirstBookLookup {
  const CatalogFirstBookLookup(this._client);

  final SupabaseClient _client;

  Future<List<BookLookupSuggestion>> findByIsbn(String isbn) async {
    final normalized = isbn.replaceAll(RegExp(r'[\\s-]'), '').toUpperCase();
    if (!RegExp(r'^(?:[0-9]{13}|[0-9]{9}[0-9X])$').hasMatch(normalized)) {
      throw ArgumentError.value(isbn, 'isbn', 'ISBN-10 or ISBN-13 required');
    }

    final kind = normalized.length == 10 ? 'isbn10' : 'isbn13';
    // Deliberately propagate catalog/network/authentication errors.
    final catalog = await _client.rpc('kv_catalog_lookup', params: {
      'p_identifier_type': kind,
      'p_identifier': normalized,
    });

    if (catalog != null) {
      if (catalog is! Map || catalog['title'] is! String) {
        throw const FormatException('Unexpected catalog lookup result');
      }
      return [
        BookLookupSuggestion(
          source: 'konvuela_catalog',
          title: catalog['title'] as String,
          attributes: Map<String, dynamic>.from(
            catalog['attributes'] as Map? ?? const {},
          ),
        ),
      ];
    }

    // No approved entry in the global catalog: invoke external provider.
    final response = await _client.functions.invoke(
      'kovunela-books-lookup',
      body: {'isbn': normalized},
    );
    if (response.status < 200 || response.status >= 300) {
      throw StateError('External book lookup unavailable: ${response.status}');
    }

    final data = response.data;
    if (data is! Map || data['books'] is! List) {
      throw const FormatException('Unexpected external book lookup result');
    }

    return (data['books'] as List).map((entry) {
      if (entry is! Map || entry['title'] is! String) {
        throw const FormatException('Malformed book suggestion');
      }
      return BookLookupSuggestion(
        source: 'google_books',
        title: entry['title'] as String,
        attributes: Map<String, dynamic>.from(
          entry['attributes'] as Map? ?? const {},
        ),
      );
    }).toList();
  }
}
