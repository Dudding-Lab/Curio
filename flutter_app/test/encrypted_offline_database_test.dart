import 'dart:io';

import 'package:curio/features/offline/encrypted_offline_database.dart';
import 'package:curio/features/offline/offline_database.dart';
import 'package:flutter_test/flutter_test.dart';

class _MemoryEncryptionKeys implements OfflineEncryptionKeyStore {
  final keys = <String, String>{};

  @override
  Future<String?> readKey(String accountId) async => keys[accountId];

  @override
  Future<void> writeKey(String accountId, String key) async {
    keys[accountId] = key;
  }

  @override
  Future<void> removeKey(String accountId) async {
    keys.remove(accountId);
  }
}

const accountA = '11111111-1111-4111-8111-111111111111';
const accountB = '22222222-2222-4222-8222-222222222222';

void main() {
  late Directory temp;
  late _MemoryEncryptionKeys keys;
  late EncryptedOfflineDatabaseFactory factory;

  setUp(() async {
    temp = await Directory.systemTemp.createTemp('kovunela_cipher_test_');
    keys = _MemoryEncryptionKeys();
    factory = EncryptedOfflineDatabaseFactory(
      projectHost: 'test.supabase.co',
      keyStore: keys,
    );
  });

  tearDown(() async {
    if (await temp.exists()) await temp.delete(recursive: true);
  });

  test('file is encrypted and original account can reopen it', () async {
    final db = await factory.openForAccount(accountId: accountA, directory: temp);
    await db.putRecord(const OfflineRecord(
      accountId: accountA,
      workspaceId: 'personal',
      kind: 'item',
      id: 'book',
      data: {'title': 'Secret collection object'},
    ));
    await db.close();

    final file = File(
      '${temp.path}/kovunela_test.supabase.co_$accountA.sqlite',
    );
    expect(await file.exists(), isTrue);
    final data = await file.readAsBytes();
    expect(data.length, greaterThan(100));
    expect(data.take(16).toList(),
        isNot('SQLite format 3'.codeUnits));
    // The entire plaintext object title must not appear in the file.
    expect(String.fromCharCodes(data).contains('Secret collection object'),
        isFalse);

    final reopened = await factory.openForAccount(
      accountId: accountA, directory: temp,
    );
    expect((await reopened.listRecords(
      accountId: accountA, workspaceId: 'personal', kind: 'item',
    )).single.data['title'], 'Secret collection object');
    await reopened.close();
  });

  test('each authenticated account receives an independent file and key',
      () async {
    final first = await factory.openForAccount(
      accountId: accountA, directory: temp,
    );
    await first.putRecord(const OfflineRecord(
      accountId: accountA, workspaceId: 'personal',
      kind: 'item', id: 'a', data: {'title': 'Account A'},
    ));
    await first.close();
    final second = await factory.openForAccount(
      accountId: accountB, directory: temp,
    );
    expect(await second.listRecords(
      accountId: accountB, workspaceId: 'personal', kind: 'item',
    ), isEmpty);
    await second.close();
    expect(keys.keys.length, 2);
    expect(keys.keys[accountA], isNot(keys.keys[accountB]));
  });

  test('wrong encryption key fails instead of returning empty records',
      () async {
    final first = await factory.openForAccount(
      accountId: accountA, directory: temp,
    );
    await first.close();
    keys.keys[accountA] = EncryptedOfflineDatabaseFactory.newRandomKey();
    await expectLater(
      factory.openForAccount(accountId: accountA, directory: temp),
      throwsA(anything),
    );
  });

  test('missing key never replaces an existing encrypted database',
      () async {
    final db = await factory.openForAccount(
      accountId: accountA, directory: temp,
    );
    await db.close();
    await keys.removeKey(accountA);
    await expectLater(
      factory.openForAccount(accountId: accountA, directory: temp),
      throwsStateError,
    );
    expect(keys.keys.containsKey(accountA), isFalse);
  });

  test('refuses plaintext legacy database instead of silently reading it',
      () async {
    final filename =
        '${temp.path}/kovunela_test.supabase.co_$accountA.sqlite';
    await File(filename).writeAsBytes([
      ...'SQLite format 3'.codeUnits,
      0,
      ...List.filled(128, 0),
    ], flush: true);
    await expectLater(
      factory.openForAccount(accountId: accountA, directory: temp),
      throwsStateError,
    );
  });

  test('rejects account identifier path traversal', () async {
    await expectLater(
      factory.openForAccount(
        accountId: '../../etc/passwd',
        directory: temp,
      ),
      throwsArgumentError,
    );
  });
}
