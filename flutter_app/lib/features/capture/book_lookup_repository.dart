import 'package:curio/features/capture/capture_suggestion.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class GoogleBookCandidate {
  const GoogleBookCandidate({
    required this.title,
    required this.sourceId,
    required this.attributes,
  });

  final String title;
  final String sourceId;
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
    );
  }

  CaptureSuggestion toSuggestion() => CaptureSuggestion(
        templateCode: 'book',
        title: title,
        attributes: attributes,
        evidence: const {'isbn': 'Google Books: exact ISBN match'},
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
