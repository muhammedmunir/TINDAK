import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Keeps the Supabase session in Android Keystore-backed storage.
///
/// Supabase's default store is plain SharedPreferences, readable by anyone who
/// can read the app's files. A refresh token there is a long-lived key to the
/// account (docs/12_SECURITY.md section 4.2, ADR-020).
///
/// Also serves as the PKCE verifier store, so no auth value ever touches
/// SharedPreferences.
final class SecureSessionStorage extends LocalStorage
    implements GotrueAsyncStorage {
  const SecureSessionStorage({
    FlutterSecureStorage storage = const FlutterSecureStorage(),
  }) : _storage = storage;

  final FlutterSecureStorage _storage;

  static const String _sessionKey = 'tindak.auth.session';
  static const String _itemPrefix = 'tindak.auth.item.';

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

  @override
  Future<String?> getItem({required String key}) =>
      _storage.read(key: '$_itemPrefix$key');

  @override
  Future<void> setItem({required String key, required String value}) =>
      _storage.write(key: '$_itemPrefix$key', value: value);

  @override
  Future<void> removeItem({required String key}) =>
      _storage.delete(key: '$_itemPrefix$key');
}
