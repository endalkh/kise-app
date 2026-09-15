/// Where the bearer token lives.
///
/// An interface, not a concrete class, so the [ApiClient] depends on the *capability* of reading a
/// token — not on `flutter_secure_storage`. Production uses [SecureAuthTokenStore] (Keychain /
/// Keystore, never SharedPreferences, never logs). A test uses [InMemoryAuthTokenStore] and never
/// touches a platform channel.
library;

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

abstract interface class AuthTokenStore {
  Future<String?> read();

  Future<void> write(String token);

  Future<void> clear();
}

/// Keychain on iOS, Keystore-backed EncryptedSharedPreferences on Android.
class SecureAuthTokenStore implements AuthTokenStore {
  SecureAuthTokenStore([FlutterSecureStorage? storage])
      : _storage = storage ??
            const FlutterSecureStorage(
              aOptions: AndroidOptions(encryptedSharedPreferences: true),
            );

  static const _key = 'kise_access_token';

  final FlutterSecureStorage _storage;

  @override
  Future<String?> read() => _storage.read(key: _key);

  @override
  Future<void> write(String token) => _storage.write(key: _key, value: token);

  @override
  Future<void> clear() => _storage.delete(key: _key);
}

/// For tests and previews. Holds the token in memory only.
class InMemoryAuthTokenStore implements AuthTokenStore {
  InMemoryAuthTokenStore([this._token]);

  String? _token;

  @override
  Future<String?> read() async => _token;

  @override
  Future<void> write(String token) async => _token = token;

  @override
  Future<void> clear() async => _token = null;
}
