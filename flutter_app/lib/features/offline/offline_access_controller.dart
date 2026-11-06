import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';

/// A previously online-authenticated account can unlock its own local
/// cache by proving possession of the device. Never interprets this as a
/// new Supabase session or grants online workspace permissions.
abstract interface class KnownDeviceStore {
  Future<String?> enrolledAccountId();
  Future<void> enroll(String accountId);
  Future<void> clear();
}

class SecureKnownDeviceStore implements KnownDeviceStore {
  SecureKnownDeviceStore([FlutterSecureStorage? storage])
      : _storage = storage ?? const FlutterSecureStorage();

  static const _key = 'kovunela_known_account_v1';
  final FlutterSecureStorage _storage;

  @override
  Future<String?> enrolledAccountId() => _storage.read(key: _key);

  @override
  Future<void> enroll(String accountId) async {
    if (accountId.trim().isEmpty) {
      throw ArgumentError('An authenticated account ID is required');
    }
    await _storage.write(key: _key, value: accountId);
  }

  @override
  Future<void> clear() => _storage.delete(key: _key);
}

abstract interface class DeviceUnlock {
  Future<bool> unlock();
}

class PlatformDeviceUnlock implements DeviceUnlock {
  PlatformDeviceUnlock([LocalAuthentication? auth])
      : _auth = auth ?? LocalAuthentication();

  final LocalAuthentication _auth;

  @override
  Future<bool> unlock() async {
    if (!await _auth.isDeviceSupported()) return false;
    return _auth.authenticate(
      localizedReason: 'Kovunela offline entsperren',
      options: const AuthenticationOptions(
        biometricOnly: false,
        stickyAuth: true,
      ),
    );
  }
}

class OfflineAccessDecision {
  const OfflineAccessDecision({
    required this.accountId,
    required this.offlineOnly,
  });

  final String accountId;
  final bool offlineOnly;
}

/// Offline unlock requires: a restored session identity on this install,
/// secure enrollment after a successful ONLINE login, and device-level
/// verification. No password/refresh token is copied to this store.
class OfflineAccessController {
  OfflineAccessController({
    required KnownDeviceStore knownDevices,
    required DeviceUnlock deviceUnlock,
  })  : _knownDevices = knownDevices,
        _deviceUnlock = deviceUnlock;

  final KnownDeviceStore _knownDevices;
  final DeviceUnlock _deviceUnlock;

  Future<void> recordOnlineLogin(String accountId) async {
    if (accountId.trim().isEmpty) {
      throw ArgumentError('Account ID is required');
    }
    await _knownDevices.enroll(accountId);
  }

  Future<OfflineAccessDecision?> unlockOffline({
    required String? restoredSessionUserId,
    required bool sessionExpired,
  }) async {
    if (restoredSessionUserId == null ||
        restoredSessionUserId.trim().isEmpty ||
        !sessionExpired) {
      return null;
    }
    final allowedId = await _knownDevices.enrolledAccountId();
    if (allowedId == null || allowedId != restoredSessionUserId) return null;
    if (!await _deviceUnlock.unlock()) return null;
    // This decision must NEVER be sent to Supabase as an authorization proof.
    return OfflineAccessDecision(
      accountId: allowedId,
      offlineOnly: true,
    );
  }

  Future<void> forgetDevice() => _knownDevices.clear();
}
