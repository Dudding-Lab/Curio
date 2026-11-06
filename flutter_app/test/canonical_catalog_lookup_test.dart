import 'package:curio/features/capture/book_lookup_repository.dart';
import 'package:curio/features/capture/canonical_catalog_repository.dart';
import 'package:flutter_test/flutter_test.dart';

class _CatalogStub implements CanonicalCatalogRepository {
  _CatalogStub(this.hit, {this.fail = false});
  final CanonicalCatalogHit? hit;
  final bool fail;
  int calls = 0;

  @override
  Future<CanonicalCatalogHit?> lookup({
    required String identifierType,
    required String identifier,
  }) async {
    calls++;
    if (fail) throw StateError('Catalog offline');
    return hit;
  }
}

class _ExternalStub implements BookLookupRepository {
  int calls = 0;

  @override
  Future<List<GoogleBookCandidate>> byIsbn(String isbn) async {
    calls++;
    return [
      GoogleBookCandidate(
        title: 'External book',
        sourceId: 'volume-1',
        attributes: {'isbn': isbn},
      ),
    ];
  }
}

const _isbn = '9783522202602';
const _hit = CanonicalCatalogHit(
  id: 'canonical-book',
  objectType: 'book',
  title: 'Curated book',
  identifier: _isbn,
  identifierType: 'isbn13',
  attributes: {'author': 'Verified author', 'publication_year': 1979},
);

void main() {
  test('checksum validation rejects mistyped identifiers without networking', () {
    expect(CatalogIdentifier.valid('isbn13', _isbn), isTrue);
    expect(CatalogIdentifier.valid('isbn13', '9783522202603'), isFalse);
    expect(CatalogIdentifier.valid('isbn10', '0306406152'), isTrue);
    expect(CatalogIdentifier.valid('isbn10', '030640615X'), isFalse);
    expect(CatalogIdentifier.valid('ean13', '4006381333931'), isTrue);
    expect(CatalogIdentifier.valid('gtin14', '00012345600012'), isTrue);
    expect(CatalogIdentifier.normalize('978-3-522-20260-2'), _isbn);
  });

  test('catalog hit is used directly without any external API call', () async {
    final catalog = _CatalogStub(_hit);
    final external = _ExternalStub();
    final lookup = CatalogFirstBookLookupRepository(
      catalog: catalog,
      external: external,
    );
    final results = await lookup.byIsbn('978-3-522-20260-2');
    expect(catalog.calls, 1);
    expect(external.calls, 0);
    expect(results.single.title, 'Curated book');
    expect(results.single.source, 'kovunela_catalog');
    expect(results.single.attributes['isbn'], _isbn);
    expect(results.single.toSuggestion().evidence['isbn'],
        contains('Kovunela'));
  });

  test('catalog miss queries external API but never publishes result', () async {
    final catalog = _CatalogStub(null);
    final external = _ExternalStub();
    final results = await CatalogFirstBookLookupRepository(
      catalog: catalog, external: external,
    ).byIsbn(_isbn);
    expect(catalog.calls, 1);
    expect(external.calls, 1);
    expect(results.single.source, 'google_books');
  });

  test('catalog query errors do not silently send data to third parties',
      () async {
    final external = _ExternalStub();
    final lookup = CatalogFirstBookLookupRepository(
      catalog: _CatalogStub(null, fail: true), external: external,
    );
    await expectLater(lookup.byIsbn(_isbn), throwsStateError);
    expect(external.calls, 0);
  });

  test('invalid identifiers cause neither catalog nor external queries',
      () async {
    final catalog = _CatalogStub(null);
    final external = _ExternalStub();
    final lookup = CatalogFirstBookLookupRepository(
      catalog: catalog, external: external,
    );
    await expectLater(lookup.byIsbn('not-an-isbn'), throwsFormatException);
    expect(catalog.calls, 0);
    expect(external.calls, 0);
  });

  test('catalog adapter rejects private, unreviewed and malformed fields', () {
    Map<String, dynamic> payload(Map<String, dynamic> attrs) => {
          'source': 'kovunela_catalog',
          'requires_review': true,
          'catalog_id': 'canonical-book',
          'object_type': 'book',
          'title': 'A book',
          'identifier_type': 'isbn13',
          'identifier': _isbn,
          'attributes': attrs,
        };
    expect(CanonicalCatalogHit.fromJson(payload({'author': 'A'}))
        .attributes['author'], 'A');
    expect(
      () => CanonicalCatalogHit.fromJson(
        payload({'owner_id': 'private-owner'}),
      ),
      throwsFormatException,
    );
    expect(
      () => CanonicalCatalogHit.fromJson(
        payload({'purchase_price': 100}),
      ),
      throwsFormatException,
    );
    expect(
      () => CanonicalCatalogHit.fromJson(
        {...payload({'author': 'A'}), 'requires_review': false},
      ),
      throwsFormatException,
    );
  });

  test('unrelated catalog objects do not replace book metadata', () async {
    final catalog = _CatalogStub(const CanonicalCatalogHit(
      id: 'camera',
      objectType: 'camera',
      title: 'Camera',
      identifier: _isbn,
      identifierType: 'isbn13',
      attributes: {'manufacturer': 'Brand'},
    ));
    final external = _ExternalStub();
    final results = await CatalogFirstBookLookupRepository(
      catalog: catalog, external: external,
    ).byIsbn(_isbn);
    expect(results.single.title, 'External book');
    expect(external.calls, 1);
  });
}
