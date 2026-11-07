import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:curio/features/konvuela/data/konvuela_repository.dart';

void main() {
  final repository = KonvuelaRepository(
    SupabaseClient('https://example.supabase.co', 'dummy-test-publishable-key'),
  );

  test('rejects empty collection titles before a remote request', () async {
    await expectLater(repository.createCollection('  '), throwsArgumentError);
  });

  test('rejects overly long collection titles before a remote request', () async {
    await expectLater(repository.createCollection('x' * 201), throwsArgumentError);
  });

  test('rejects empty item titles before a remote request', () async {
    await expectLater(repository.createItem('  '), throwsArgumentError);
  });

  test('rejects overly long item titles before a remote request', () async {
    await expectLater(repository.createItem('x' * 201), throwsArgumentError);
  });
}
