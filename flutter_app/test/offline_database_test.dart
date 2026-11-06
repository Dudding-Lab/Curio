import 'package:curio/features/offline/offline_database.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late OfflineDatabase db;

  setUp(() {
    db = OfflineDatabase(NativeDatabase.memory());
  });
  tearDown(() async {
    await db.close();
  });

  OfflineRecord item({
    String account = 'account-a',
    String workspace = 'private-a',
    String id = 'item-1',
    String title = 'Book',
  }) => OfflineRecord(
        accountId: account,
        workspaceId: workspace,
        kind: 'item',
        id: id,
        data: {'title': title, 'attributes': <String, dynamic>{}},
      );

  test('offline writes persist a record and an outbox entry together', () async {
    final mutationId = await db.putRecord(item());
    final stored = await db.getRecord(
      accountId: 'account-a',
      workspaceId: 'private-a',
      kind: 'item',
      id: 'item-1',
    );
    expect(stored?.data['title'], 'Book');
    final queue = await db.pendingForAccount('account-a');
    expect(queue, hasLength(1));
    expect(queue.first.id, mutationId);
    expect(queue.first.operation, 'upsert');
    expect(queue.first.localRevision, 1);
  });

  test('same record key is isolated by account and workspace', () async {
    await db.putRecord(item(title: 'Private A'));
    await db.putRecord(item(account: 'account-b', workspace: 'private-a',
        title: 'Private B'));
    await db.putRecord(item(workspace: 'household-a', title: 'Shared A'));
    expect((await db.listRecords(
        accountId: 'account-a', workspaceId: 'private-a', kind: 'item'))
        .single.data['title'], 'Private A');
    expect((await db.listRecords(
        accountId: 'account-b', workspaceId: 'private-a', kind: 'item'))
        .single.data['title'], 'Private B');
    expect((await db.listRecords(
        accountId: 'account-a', workspaceId: 'household-a', kind: 'item'))
        .single.data['title'], 'Shared A');
    expect(await db.pendingForAccount('account-a'), hasLength(2));
    expect(await db.pendingForAccount('account-b'), hasLength(1));
  });

  test('edits maintain ordered durable intent with monotonic revisions',
      () async {
    await db.putRecord(item(title: 'First'));
    await db.putRecord(item(title: 'Second'));
    final queue = await db.pendingForAccount('account-a');
    expect(queue, hasLength(2));
    expect(queue.map((change) => change.localRevision), [1, 2]);
    expect(queue.last.payload['title'], 'Second');
    expect((await db.listRecords(
      accountId: 'account-a',
      workspaceId: 'private-a',
      kind: 'item',
    )).single.data['title'], 'Second');
  });

  test('deletions become tombstones and remain pending until acknowledged',
      () async {
    await db.putRecord(item());
    final deletionId = await db.deleteRecord(
      accountId: 'account-a', workspaceId: 'private-a',
      kind: 'item', id: 'item-1',
    );
    expect(await db.listRecords(
      accountId: 'account-a', workspaceId: 'private-a', kind: 'item',
    ), isEmpty);
    final tombstone = await db.getRecord(
      accountId: 'account-a', workspaceId: 'private-a',
      kind: 'item', id: 'item-1', includeDeleted: true,
    );
    expect(tombstone?.deleted, isTrue);
    final queue = await db.pendingForAccount('account-a');
    expect(queue.last.id, deletionId);
    expect(queue.last.operation, 'delete');
    expect(queue.last.localRevision, 2);
  });

  test('acknowledgements cannot remove another account outbox entry',
      () async {
    final mutationId = await db.putRecord(item());
    expect(await db.acknowledgeMutation(
      accountId: 'account-b', mutationId: mutationId,
    ), isFalse);
    expect(await db.pendingForAccount('account-a'), hasLength(1));
    expect(await db.acknowledgeMutation(
      accountId: 'account-a', mutationId: mutationId,
    ), isTrue);
    expect(await db.pendingForAccount('account-a'), isEmpty);
    expect(await db.acknowledgeMutation(
      accountId: 'account-a', mutationId: mutationId,
    ), isFalse);
  });

  test('invalid writes do not create records or pending mutations', () async {
    await expectLater(
      db.putRecord(item(account: '')),
      throwsArgumentError,
    );
    await expectLater(
      db.putRecord(const OfflineRecord(
        accountId: 'account-a', workspaceId: 'private-a',
        kind: 'unknown', id: 'bad', data: {},
      )),
      throwsArgumentError,
    );
    expect(await db.pendingForAccount('account-a'), isEmpty);
  });

  test('all offline entity types are supported in shared storage', () async {
    for (final kind in [
      'item', 'collection', 'category', 'template', 'workspace'
    ]) {
      await db.putRecord(OfflineRecord(
        accountId: 'account-a',
        workspaceId: 'private-a',
        kind: kind,
        id: 'same-id',
        data: {'kind': kind},
      ));
      expect(await db.listRecords(
        accountId: 'account-a', workspaceId: 'private-a', kind: kind,
      ), hasLength(1));
    }
    expect(await db.pendingForAccount('account-a'), hasLength(5));
  });
}
