import 'package:curio/features/taxonomy/personal_taxonomy_repository.dart';
import 'package:curio/l10n/app_localizations.dart';
import 'package:curio/screens/taxonomy/personal_object_types_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeTaxonomy implements PersonalTaxonomyRepository {
  @override
  Future<List<PersonalObjectType>> listObjectTypes() async => [
        const PersonalObjectType(
          id: 'camera-type',
          title: 'Kamera',
          templateVersionId: 'version-1',
          fields: {'manufacturer': 'text', 'year': 'number'},
        ),
      ];
  @override
  Future<List<PersonalCategory>> listCategories() async => [];
  @override
  Future<String> createCategory({required String code, required String label}) =>
      throw UnimplementedError();
  @override
  Future<String> createObjectType({
    required String title,
    required Map<String, String> fields,
  }) => throw UnimplementedError();
  @override
  Future<String> createTypedItem({
    required String title,
    String description = '',
    String? categoryId,
    String? templateVersionId,
    Map<String, dynamic> attributes = const {},
  }) => throw UnimplementedError();
}

void main() {
  test('type versions preserve the declared metadata field types', () {
    final type = PersonalObjectType.fromJson({
      'id': 'type-id',
      'title': 'Books',
      'template_version_id': 'version-id',
      'field_schema': {'author': 'text', 'pages': 'number'},
    });
    expect(type.title, 'Books');
    expect(type.templateVersionId, 'version-id');
    expect(type.fields, {'author': 'text', 'pages': 'number'});
  });

  test('category is distinct from object type', () {
    final category = PersonalCategory.fromJson({
      'id': 'category-id',
      'code': 'technology',
      'label': 'Technology',
    });
    expect(category.code, 'technology');
  });

  testWidgets('object type list displays fields without enabling writes',
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
        home: PersonalObjectTypesScreen(repository: _FakeTaxonomy()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Meine Objekttypen'), findsOneWidget);
    expect(find.text('Kamera'), findsOneWidget);
    expect(find.text('2 Eigenschaften'), findsOneWidget);
    expect(find.byType(FloatingActionButton), findsNothing);
  });
}
