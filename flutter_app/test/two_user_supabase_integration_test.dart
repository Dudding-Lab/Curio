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
