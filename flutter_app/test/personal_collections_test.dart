import 'package:curio/features/collections/personal_collection_repository.dart';
import 'package:curio/l10n/app_localizations.dart';
import 'package:curio/screens/collections/personal_collections_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeCollections implements PersonalCollectionRepository {
  _FakeCollections(this.collections);

  final List<PersonalCollection> collections;
  @override
  Future<List<PersonalCollection>> list() async => collections;

  @override
  Future<String> create({required String title, String description = ''}) =>
      throw UnimplementedError();

  @override
  Future<void> addItem({required String itemId, required String collectionId}) =>
      throw UnimplementedError();
}

void main() {
  test('personal collection parses RPC result', () {
    final model = PersonalCollection.fromJson({
      'id': 'collection-1',
      'title': 'Cameras',
      'description': null,
      'created_at': '2026-11-06T07:00:00Z',
    });
    expect(model.id, 'collection-1');
    expect(model.title, 'Cameras');
    expect(model.description, isEmpty);
  });

  testWidgets('personal collection list uses injected repository',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('de'),
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: PersonalCollectionsScreen(
          repository: _FakeCollections([
            PersonalCollection(
              id: 'collection-1',
              title: 'Meine Kameras',
              description: 'Vintage',
              createdAt: DateTime.utc(2026, 11, 6),
            ),
          ]),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Meine Sammlungen'), findsOneWidget);
    expect(find.text('Meine Kameras'), findsOneWidget);
    expect(find.text('Vintage'), findsOneWidget);
  });
}
