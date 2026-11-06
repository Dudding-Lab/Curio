import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Opt-in integration suite using TWO real Supabase Auth accounts.
///
/// Run only against the disposable, non-production Curio project.
/// Never commit passwords or access tokens. Tests create real item rows.
void main() {
  const url = String.fromEnvironment('KOVUNELA_TEST_SUPABASE_URL');
  const key = String.fromEnvironment('KOVUNELA_TEST_SUPABASE_PUBLISHABLE_KEY');
  const emailA = String.fromEnvironment('KOVUNELA_TEST_EMAIL_A');
  const emailB = String.fromEnvironment('KOVUNELA_TEST_EMAIL_B');
  const passwordA = String.fromEnvironment('KOVUNELA_TEST_PASSWORD_A');
  const passwordB = String.fromEnvironment('KOVUNELA_TEST_PASSWORD_B');

  final configured = url.isNotEmpty &&
      key.isNotEmpty &&
      emailA.isNotEmpty &&
      emailB.isNotEmpty &&
      passwordA.isNotEmpty &&
      passwordB.isNotEmpty &&
      emailA != emailB;

  test('real Auth users cannot create or list each other\'s items', () async {
    final a = SupabaseClient(url, key);
    final b = SupabaseClient(url, key);
    final anonymous = SupabaseClient(url, key);
    try {
      await a.auth.signInWithPassword(email: emailA, password: passwordA);
      await b.auth.signInWithPassword(email: emailB, password: passwordB);

      final userA = a.auth.currentUser?.id;
      final userB = b.auth.currentUser?.id;
      expect(userA, isNotNull);
      expect(userB, isNotNull);
      expect(userA, isNot(userB));

      Future<List<dynamic>> list(SupabaseClient client) async {
        final result = await client.rpc('kv_list_personal_items');
        return result as List<dynamic>;
      }

      final marker = DateTime.now().microsecondsSinceEpoch.toString();
      final titleA = 'Kovunela security A $marker';
      final titleB = 'Kovunela security B $marker';

      final idA = await a.rpc('kv_create_personal_item', params: {
        'p_title': titleA,
        'p_description': 'Integration test A',
      });
      expect(idA, isA<String>());
      expect((idA as String).isNotEmpty, isTrue);

      final listA = await list(a);
      final listB = await list(b);
      expect(listA.any((row) => (row as Map)['id'] == idA), isTrue);
      expect(listB.any((row) => (row as Map)['id'] == idA), isFalse);

      final idB = await b.rpc('kv_create_personal_item', params: {
        'p_title': titleB,
        'p_description': 'Integration test B',
      });
      expect(idB, isA<String>());
      expect((idB as String).isNotEmpty, isTrue);
      expect((await list(b)).any((row) => (row as Map)['id'] == idB), isTrue);
      expect((await list(a)).any((row) => (row as Map)['id'] == idB), isFalse);

      final collectionA = await a.rpc('kv_create_personal_collection', params: {
        'p_title': 'Private A $marker',
        'p_description': '',
      });
      expect(collectionA, isA<String>());
      final collectionB = await b.rpc('kv_create_personal_collection', params: {
        'p_title': 'Private B $marker',
        'p_description': '',
      });
      expect(collectionB, isA<String>());

      Future<List<dynamic>> listCollections(SupabaseClient client) async =>
          await client.rpc('kv_list_personal_collections') as List<dynamic>;
      expect(
        (await listCollections(a)).any((row) => (row as Map)['id'] == collectionA),
        isTrue,
      );
      expect(
        (await listCollections(b)).any((row) => (row as Map)['id'] == collectionA),
        isFalse,
      );

      final added = await a.rpc('kv_add_personal_item_to_collection', params: {
        'p_item_id': idA,
        'p_collection_id': collectionA,
      });
      expect(added, true);
      await expectLater(
        b.rpc('kv_add_personal_item_to_collection', params: {
          'p_item_id': idA,
          'p_collection_id': collectionB,
        }),
        throwsA(isA<PostgrestException>()),
      );
      await expectLater(
        a.rpc('kv_add_personal_item_to_collection', params: {
          'p_item_id': idA,
          'p_collection_id': collectionB,
        }),
        throwsA(isA<PostgrestException>()),
      );
      await expectLater(
        anonymous.rpc('kv_list_personal_collections'),
        throwsA(isA<PostgrestException>()),
      );

      final categoryA = await a.rpc('kv_create_personal_category', params: {
        'p_code': 'camera_$marker',
        'p_label': 'Cameras',
      });
      expect(categoryA, isA<String>());
      final typeA = await a.rpc('kv_create_personal_object_type', params: {
        'p_title': 'Camera $marker',
        'p_fields': {'manufacturer': 'text', 'year': 'number'},
      });
      expect(typeA, isA<String>());
      final typesA =
          await a.rpc('kv_list_personal_object_types') as List<dynamic>;
      final versionA = (typesA.cast<Map>().firstWhere(
        (row) => row['id'] == typeA,
      ))['template_version_id'] as String;
      final typedItem = await a.rpc('kv_create_typed_personal_item', params: {
        'p_title': 'Camera with metadata',
        'p_description': '',
        'p_category_id': categoryA,
        'p_template_version_id': versionA,
        'p_attributes': {'manufacturer': 'Example', 'year': 2001},
      });
      expect(typedItem, isA<String>());
      expect(
        (await b.rpc('kv_list_personal_categories') as List<dynamic>)
            .any((row) => (row as Map)['id'] == categoryA),
        isFalse,
      );
      await expectLater(
        b.rpc('kv_create_typed_personal_item', params: {
          'p_title': 'Cross-workspace injection',
          'p_description': '',
          'p_category_id': categoryA,
          'p_template_version_id': versionA,
          'p_attributes': <String, dynamic>{},
        }),
        throwsA(isA<PostgrestException>()),
      );
      await expectLater(
        a.rpc('kv_create_typed_personal_item', params: {
          'p_title': 'Wrong attribute type',
          'p_description': '',
          'p_category_id': categoryA,
          'p_template_version_id': versionA,
          'p_attributes': {'year': 'not a number'},
        }),
        throwsA(isA<PostgrestException>()),
      );
      await expectLater(
        anonymous.rpc('kv_list_personal_object_types'),
        throwsA(isA<PostgrestException>()),
      );

      final standards =
          await a.rpc('kv_list_standard_templates') as List<dynamic>;
      final book = standards.cast<Map>().firstWhere(
        (row) => row['code'] == 'book',
      );
      expect(book['field_schema'], isA<Map>());
      final derivedA = await a.rpc('kv_derive_standard_template', params: {
        'p_standard_id': book['id'],
        'p_title': 'Books with notes $marker',
        'p_added_fields': {'reading_status': 'text'},
      });
      expect(derivedA, isA<String>());
      final ownTypes =
          await a.rpc('kv_list_personal_object_types') as List<dynamic>;
      final derivedRow = ownTypes.cast<Map>().firstWhere(
        (row) => row['id'] == derivedA,
      );
      expect(
        (derivedRow['field_schema'] as Map)['reading_status'],
        'text',
      );
      expect(
        (await b.rpc('kv_list_personal_object_types') as List<dynamic>)
            .any((row) => (row as Map)['id'] == derivedA),
        isFalse,
      );
      await expectLater(
        a.rpc('kv_derive_standard_template', params: {
          'p_standard_id': book['id'],
          'p_title': 'Invalid override',
          'p_added_fields': {'isbn': 'number'},
        }),
        throwsA(isA<PostgrestException>()),
      );
      await expectLater(
        b.rpc('kv_share_personal_template', params: {
          'p_template_id': derivedA,
          'p_target_workspace_id': '00000000-0000-4000-8000-000000000000',
        }),
        throwsA(isA<PostgrestException>()),
      );
      await expectLater(
        a.rpc('kv_share_personal_template', params: {
          'p_template_id': derivedA,
          'p_target_workspace_id': '00000000-0000-4000-8000-000000000000',
        }),
        throwsA(isA<PostgrestException>()),
      );
      await expectLater(
        anonymous.rpc('kv_list_standard_templates'),
        throwsA(isA<PostgrestException>()),
      );

      await expectLater(
        anonymous.rpc('kv_create_personal_item', params: {
          'p_title': 'Unauthorized',
          'p_description': '',
        }),
        throwsA(isA<PostgrestException>()),
      );
      await expectLater(
        anonymous.rpc('kv_list_personal_items'),
        throwsA(isA<PostgrestException>()),
      );
      await expectLater(
        a.rpc('kv_create_personal_item', params: {
          'p_title': '   ',
          'p_description': '',
        }),
        throwsA(isA<PostgrestException>()),
      );
    } finally {
      await a.dispose();
      await b.dispose();
      await anonymous.dispose();
    }
  }, skip: !configured);
}
