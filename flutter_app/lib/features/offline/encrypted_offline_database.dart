import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:curio/features/offline/offline_database.dart';
import 'package:drift/native.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path_provider/path_provider.dart';

/// Abstracts the OS key store to enable tests without a device.
abstract interface class OfflineEncryptionKeyStore {
  Future<String?> readKey(String accountId);
  Future<void> writeKey(String accountId, String key);
  Future<void> removeKey(String accountId);
}

/// The database encryption key is held in Android Keystore / iOS Keychain
/// protected storage; it is not derived from an account password or JWT.
class SecureOfflineEncryptionKeyStore implements OfflineEncryptionKeyStore {
  SecureOfflineEncryptionKeyStore({
    required this.projectHost,
    FlutterSecureStorage? storage,
  }) : _storage = storage ?? const FlutterSecureStorage();

  final String projectHost;
  final FlutterSecureStorage _storage;

  String _keyName(String accountId) =>
      'kovunela_offline_db_v1_${projectHost}_${accountId}';

  @override
  Future<String?> readKey(String accountId) =>
      _storage.read(key: _keyName(accountId));

  @override
  Future<void> writeKey(String accountId, String key) =>
      _storage.write(key: _keyName(accountId), value: key);

  @override
  Future<void> removeKey(String accountId) =>
      _storage.delete(key: _keyName(accountId));
}

/// Fail-closed production opener. A bad/missing key never falls back to
/// plaintext, and an existing database is never silently overwritten.
class EncryptedOfflineDatabaseFactory {
  EncryptedOfflineDatabaseFactory({
    required this.projectHost,
    required OfflineEncryptionKeyStore keyStore,
  }) : _keyStore = keyStore;

  final String projectHost;
  final OfflineEncryptionKeyStore _keyStore;

  static final _accountPattern = RegExp(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[1-8][0-9a-fA-F]{3}-[89abAB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}$',
  );

  static String newRandomKey() {
    final random = Random.secure();
    final bytes = List<int>.generate(32, (_) => random.nextInt(256));
    return base64UrlEncode(bytes);
  }

  Future<OfflineDatabase> openForAccount({
    required String accountId,
    Directory? directory,
  }) async {
    if (!_accountPattern.hasMatch(accountId) ||
        !RegExp(r'^[a-zA-Z0-9.-]{1,255}$').hasMatch(projectHost)) {
      throw ArgumentError('Invalid account or project identifier');
    }
    final base = directory ?? await getApplicationSupportDirectory();
    if (!await base.exists()) await base.create(recursive: true);
    final file = File('${base.path}/kovunela_${projectHost}_${accountId}.sqlite');
    final exists = await file.exists();
    var key = await _keyStore.readKey(accountId);
    if (key == null) {
      if (exists) {
        throw StateError('Existing local database has no encryption key');
      }
      key = newRandomKey();
      await _keyStore.writeKey(accountId, key);
    }
    if (key.length != 44 || !RegExp(r'^[A-Za-z0-9_-]{43}=$').hasMatch(key)) {
      throw StateError('Invalid stored encryption key');
    }
    if (exists) {
      final handle = await file.open();
      try {
        final signature = await handle.read(16);
        if (signature.length == 16 &&
            utf8.decode(signature, allowMalformed: true)
                .startsWith('SQLite format 3')) {
          throw StateError('Refusing plaintext SQLite database');
        }
      } finally {
        await handle.close();
      }
    }

    // The sqlite3mc native library is selected through pubspec build hooks.
    // Verify its presence at RUNTIME, even in release builds (not just assert).
    // An ordinary SQLite library would silently ignore PRAGMA key.
    final executor = NativeDatabase.createInBackground(
      file,
      setup: (raw) {
        if (raw.select('PRAGMA cipher;').isEmpty) {
          throw StateError('Encrypted SQLite backend is not installed');
        }
        final escaped = key!.replaceAll("'", "''");
        raw.execute("PRAGMA key = '${escaped}';");
        // This query must fail if the file is not decryptable with this key.
        raw.select('SELECT count(*) FROM sqlite_master');
      },
    );
    final db = OfflineDatabase(executor);
    try {
      // Opening the connection initializes schema after successful decryption.
      await db.customSelect('SELECT count(*) AS n FROM offline_records')
          .getSingle();
      return db;
    } catch (_) {
      await db.close();
      rethrow;
    }
  }
}
