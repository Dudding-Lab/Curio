import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Persists the Supabase session in platform secure storage instead of
/// SharedPreferences. Logout removes this token; never save passwords here.
///
/// This is deliberately isolated from the offline-device enrollment marker:
/// a session proves server identity only while the token remains valid;
/// the device marker proves only that an account previously logged in.
class SecureSupabaseSessionStorage extends LocalStorage {
  SecureSupabaseSessionStorage({
    required String projectUrl,
    FlutterSecureStorage? storage,
  })  : _storage = storage ?? const FlutterSecureStorage(),
        _sessionKey = 'kovunela_auth_v1_${Uri.parse(projectUrl).host}';

  final String _sessionKey;
  final FlutterSecureStorage _storage;

  @override
  Future<void> initialize() async {}

  @override
  Future<bool> hasAccessToken() => _storage.containsKey(key: _sessionKey);

  @override
  Future<String?> accessToken() => _storage.read(key: _sessionKey);

  @override
  Future<void> persistSession(String persistSessionString) =>
      _storage.write(key: _sessionKey, value: persistSessionString);

  @override
  Future<void> removePersistedSession() => _storage.delete(key: _sessionKey);
}
