import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Nơi lưu **refresh token** (bí mật dài hạn). Access token chỉ nằm trong bộ nhớ.
abstract interface class TokenStore {
  Future<String?> readRefreshToken();
  Future<void> saveRefreshToken(String token);
  Future<void> clear();
}

/// Keychain (iOS) / EncryptedSharedPreferences (Android) qua `flutter_secure_storage`.
class SecureTokenStore implements TokenStore {
  SecureTokenStore([FlutterSecureStorage? storage])
    : _storage = storage ?? const FlutterSecureStorage();

  static const _key = 'core_cd.refresh_token';
  final FlutterSecureStorage _storage;

  @override
  Future<String?> readRefreshToken() => _storage.read(key: _key);

  @override
  Future<void> saveRefreshToken(String token) =>
      _storage.write(key: _key, value: token);

  @override
  Future<void> clear() => _storage.delete(key: _key);
}

/// Dùng cho test.
class InMemoryTokenStore implements TokenStore {
  InMemoryTokenStore([this._token]);
  String? _token;

  @override
  Future<String?> readRefreshToken() async => _token;

  @override
  Future<void> saveRefreshToken(String token) async => _token = token;

  @override
  Future<void> clear() async => _token = null;
}
