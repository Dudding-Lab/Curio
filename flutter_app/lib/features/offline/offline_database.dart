import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

/// Persisted locally; each row is strictly scoped to one account and space.
/// This first iteration is not connected to the live UI or Supabase writes.
class OfflineRecord {
  const OfflineRecord({
    required this.accountId,
    required this.workspaceId,
    required this.kind,
    required this.id,
    required this.data,
    this.deleted = false,
    this.serverVersion,
  });

  final String accountId;
  final String workspaceId;
  final String kind;
  final String id;
  final Map<String, dynamic> data;
  final bool deleted;
  final int? serverVersion;
}

class QueuedChange {
  const QueuedChange({
    required this.id,
    required this.accountId,
    required this.workspaceId,
    required this.kind,
    required this.recordId,
    required this.operation,
    required this.payload,
    required this.localRevision,
    this.baseServerVersion,
  });

  final String id;
  final String accountId;
  final String workspaceId;
  final String kind;
  final String recordId;
  final String operation;
  final Map<String, dynamic> payload;
  final int localRevision;
  final int? baseServerVersion;
}

/// Local-only SQLite foundation. No network operations, no auto-sync.
/// A future sync worker must apply mutations through authorized, idempotent
/// server RPCs, and must not merely replay arbitrary client-side SQL.
class OfflineDatabase extends GeneratedDatabase {
  /// Production callers must supply an encrypted executor. This prevents
  /// accidentally creating an unencrypted on-device database.
  OfflineDatabase(super.executor);

  @override
  int get schemaVersion => 1;

  @override
  Iterable<TableInfo<Table, dynamic>> get allSchemaEntities => const [];

  @override
  Iterable<TableInfo<Table, dynamic>> get allTables => const [];

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (migrator) async {
          await customStatement('''
            CREATE TABLE offline_records (
              account_id TEXT NOT NULL,
              workspace_id TEXT NOT NULL,
              kind TEXT NOT NULL CHECK(kind IN
                ('item', 'collection', 'category', 'template', 'workspace')),
              record_id TEXT NOT NULL,
              payload_json TEXT NOT NULL,
              deleted INTEGER NOT NULL DEFAULT 0 CHECK(deleted IN (0,1)),
              local_revision INTEGER NOT NULL DEFAULT 1 CHECK(local_revision > 0),
              server_version INTEGER CHECK(server_version IS NULL OR server_version >= 0),
              updated_at_ms INTEGER NOT NULL,
              PRIMARY KEY (account_id, workspace_id, kind, record_id)
            )
          ''');
          await customStatement('''
            CREATE TABLE pending_mutations (
              mutation_id TEXT NOT NULL PRIMARY KEY,
              account_id TEXT NOT NULL,
              workspace_id TEXT NOT NULL,
              kind TEXT NOT NULL CHECK(kind IN
                ('item', 'collection', 'category', 'template', 'workspace')),
              record_id TEXT NOT NULL,
              operation TEXT NOT NULL CHECK(operation IN ('upsert', 'delete')),
              payload_json TEXT NOT NULL,
              local_revision INTEGER NOT NULL CHECK(local_revision > 0),
              base_server_version INTEGER CHECK(
                base_server_version IS NULL OR base_server_version >= 0),
              created_at_ms INTEGER NOT NULL,
              FOREIGN KEY (account_id, workspace_id, kind, record_id)
                REFERENCES offline_records(account_id, workspace_id, kind, record_id)
            )
          ''');
          await customStatement('''
            CREATE INDEX pending_mutations_by_account
            ON pending_mutations (account_id, created_at_ms, mutation_id)
          ''');
        },
      );

  static const _kinds = {
    'item', 'collection', 'category', 'template', 'workspace'
  };
  static const _uuid = Uuid();

  void _validateScope(String accountId, String workspaceId) {
    if (accountId.trim().isEmpty || workspaceId.trim().isEmpty) {
      throw ArgumentError('A user and workspace are required');
    }
  }

  void _validateRecord(OfflineRecord record) {
    _validateScope(record.accountId, record.workspaceId);
    if (record.id.trim().isEmpty || !_kinds.contains(record.kind)) {
      throw ArgumentError('Invalid record ID or kind');
    }
    if (record.serverVersion != null && record.serverVersion! < 0) {
      throw ArgumentError('Invalid server version');
    }
    if (utf8.encode(jsonEncode(record.data)).length > 32768) {
      throw ArgumentError('Record exceeds local metadata limit');
    }
  }

  /// One ACID transaction: the record and its durable sync intent are
  /// committed together. A crash cannot persist only one half.
  Future<String> putRecord(OfflineRecord record) async {
    _validateRecord(record);
    final encoded = jsonEncode(record.data);
    final changeId = _uuid.v4();
    final now = DateTime.now().toUtc().millisecondsSinceEpoch;
    await transaction(() async {
      final existing = await customSelect(
        '''SELECT local_revision, server_version FROM offline_records
           WHERE account_id = ? AND workspace_id = ?
           AND kind = ? AND record_id = ?''',
        variables: [
          Variable.withString(record.accountId),
          Variable.withString(record.workspaceId),
          Variable.withString(record.kind),
          Variable.withString(record.id),
        ],
      ).getSingleOrNull();
      final revision = (existing?.read<int>('local_revision') ?? 0) + 1;
      // Preserve the last server revision until the sync engine confirms it.
      final baseVersion = existing?.readNullable<int>('server_version') ??
          record.serverVersion;
      await customStatement(
        '''INSERT INTO offline_records
           (account_id, workspace_id, kind, record_id, payload_json,
            deleted, local_revision, server_version, updated_at_ms)
           VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
           ON CONFLICT(account_id, workspace_id, kind, record_id) DO UPDATE SET
             payload_json = excluded.payload_json,
             deleted = excluded.deleted,
             local_revision = excluded.local_revision,
             updated_at_ms = excluded.updated_at_ms''',
        [
          record.accountId, record.workspaceId, record.kind, record.id,
          encoded, record.deleted ? 1 : 0, revision, baseVersion, now,
        ],
      );
      await customStatement(
        '''INSERT INTO pending_mutations
           (mutation_id, account_id, workspace_id, kind, record_id,
            operation, payload_json, local_revision, base_server_version,
            created_at_ms)
           VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)''',
        [
          changeId, record.accountId, record.workspaceId, record.kind,
          record.id, record.deleted ? 'delete' : 'upsert', encoded,
          revision, baseVersion, now,
        ],
      );
    });
    return changeId;
  }

  /// A delete is a tombstone, not an immediate loss of sync history.
  Future<String> deleteRecord({
    required String accountId,
    required String workspaceId,
    required String kind,
    required String id,
  }) async {
    _validateScope(accountId, workspaceId);
    final old = await getRecord(
      accountId: accountId, workspaceId: workspaceId, kind: kind, id: id,
      includeDeleted: true,
    );
    if (old == null) throw StateError('Cannot delete a missing record');
    return putRecord(OfflineRecord(
      accountId: accountId, workspaceId: workspaceId, kind: kind,
      id: id, data: old.data, deleted: true,
    ));
  }

  Future<OfflineRecord?> getRecord({
    required String accountId,
    required String workspaceId,
    required String kind,
    required String id,
    bool includeDeleted = false,
  }) async {
    _validateScope(accountId, workspaceId);
    final rows = await customSelect(
      '''SELECT * FROM offline_records
         WHERE account_id = ? AND workspace_id = ?
           AND kind = ? AND record_id = ?
           AND (? = 1 OR deleted = 0)''',
      variables: [
        Variable.withString(accountId), Variable.withString(workspaceId),
        Variable.withString(kind), Variable.withString(id),
        Variable.withInt(includeDeleted ? 1 : 0),
      ],
    ).get();
    return rows.isEmpty ? null : _decodeRecord(rows.single);
  }

  Future<List<OfflineRecord>> listRecords({
    required String accountId,
    required String workspaceId,
    required String kind,
  }) async {
    _validateScope(accountId, workspaceId);
    final rows = await customSelect(
      '''SELECT * FROM offline_records WHERE account_id = ?
        AND workspace_id = ? AND kind = ? AND deleted = 0
        ORDER BY updated_at_ms DESC, record_id''',
      variables: [
        Variable.withString(accountId), Variable.withString(workspaceId),
        Variable.withString(kind),
      ],
    ).get();
    return rows.map(_decodeRecord).toList(growable: false);
  }

  Future<List<QueuedChange>> pendingForAccount(String accountId) async {
    if (accountId.trim().isEmpty) throw ArgumentError('Account required');
    final rows = await customSelect(
      '''SELECT * FROM pending_mutations WHERE account_id = ?
         ORDER BY created_at_ms, rowid''',
      variables: [Variable.withString(accountId)],
    ).get();
    return rows.map((row) => QueuedChange(
      id: row.read<String>('mutation_id'),
      accountId: row.read<String>('account_id'),
      workspaceId: row.read<String>('workspace_id'),
      kind: row.read<String>('kind'),
      recordId: row.read<String>('record_id'),
      operation: row.read<String>('operation'),
      payload: Map<String, dynamic>.from(
        jsonDecode(row.read<String>('payload_json')) as Map,
      ),
      localRevision: row.read<int>('local_revision'),
      baseServerVersion: row.readNullable<int>('base_server_version'),
    )).toList(growable: false);
  }

  /// Only call after the server has *durably* acknowledged this exact
  /// idempotency key and version. Does not change the local record.
  Future<bool> acknowledgeMutation({
    required String accountId,
    required String mutationId,
  }) async {
    if (accountId.trim().isEmpty || mutationId.trim().isEmpty) {
      throw ArgumentError('Account and mutation required');
    }
    return transaction(() async {
      final exists = await customSelect(
        'SELECT mutation_id FROM pending_mutations WHERE account_id=? AND mutation_id=?',
        variables: [
          Variable.withString(accountId),
          Variable.withString(mutationId),
        ],
      ).getSingleOrNull();
      if (exists == null) return false;
      await customStatement(
        'DELETE FROM pending_mutations WHERE account_id=? AND mutation_id=?',
        [accountId, mutationId],
      );
      return true;
    });
  }

  OfflineRecord _decodeRecord(QueryRow row) => OfflineRecord(
    accountId: row.read<String>('account_id'),
    workspaceId: row.read<String>('workspace_id'),
    kind: row.read<String>('kind'),
    id: row.read<String>('record_id'),
    data: Map<String, dynamic>.from(
      jsonDecode(row.read<String>('payload_json')) as Map,
    ),
    deleted: row.read<int>('deleted') != 0,
    serverVersion: row.readNullable<int>('server_version'),
  );
}
