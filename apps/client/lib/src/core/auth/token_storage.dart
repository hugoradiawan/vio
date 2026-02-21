import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Secure token storage for authentication tokens.
///
/// Uses secure storage on native platforms and [SharedPreferences] on web.
class TokenStorage {
  TokenStorage._({
    TokenStorageBackend? secureBackend,
    TokenStorageBackend? webBackend,
    bool Function()? webChecker,
  })  : _secureBackend = secureBackend ?? const _SecureStorageBackend(),
        _webBackend = webBackend ?? const _SharedPreferencesBackend(),
        _isWeb = webChecker ?? (() => kIsWeb);

  static final TokenStorage instance = TokenStorage._();

  @visibleForTesting
  factory TokenStorage.forTesting({
    required TokenStorageBackend secureBackend,
    required TokenStorageBackend webBackend,
    required bool Function() webChecker,
  }) {
    return TokenStorage._(
      secureBackend: secureBackend,
      webBackend: webBackend,
      webChecker: webChecker,
    );
  }

  static const _accessTokenKey = 'vio_access_token';
  static const _refreshTokenKey = 'vio_refresh_token';

  final TokenStorageBackend _secureBackend;
  final TokenStorageBackend _webBackend;
  final bool Function() _isWeb;

  /// Save both access and refresh tokens.
  Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
  }) async {
    if (_isWeb()) {
      await _webBackend.write(_accessTokenKey, accessToken);
      await _webBackend.write(_refreshTokenKey, refreshToken);
      debugPrint('[TokenStorage] Tokens saved');
      return;
    }

    try {
      await _secureBackend.write(_accessTokenKey, accessToken);
      await _secureBackend.write(_refreshTokenKey, refreshToken);
    } catch (error) {
      debugPrint(
        '[TokenStorage] Secure save failed, using fallback storage: $error',
      );
      await _webBackend.write(_accessTokenKey, accessToken);
      await _webBackend.write(_refreshTokenKey, refreshToken);
    }
    debugPrint('[TokenStorage] Tokens saved');
  }

  /// Get the stored access token, or null if not set.
  Future<String?> getAccessToken() async {
    return _readWithNativeFallback(_accessTokenKey);
  }

  /// Get the stored refresh token, or null if not set.
  Future<String?> getRefreshToken() async {
    return _readWithNativeFallback(_refreshTokenKey);
  }

  /// Clear all stored tokens (logout).
  Future<void> clearTokens() async {
    if (_isWeb()) {
      await _webBackend.delete(_accessTokenKey);
      await _webBackend.delete(_refreshTokenKey);
      debugPrint('[TokenStorage] Tokens cleared');
      return;
    }

    try {
      await _secureBackend.delete(_accessTokenKey);
      await _secureBackend.delete(_refreshTokenKey);
    } catch (error) {
      debugPrint(
        '[TokenStorage] Secure clear failed, clearing fallback storage: $error',
      );
    }

    await _webBackend.delete(_accessTokenKey);
    await _webBackend.delete(_refreshTokenKey);
    debugPrint('[TokenStorage] Tokens cleared');
  }

  /// Check whether tokens are stored (quick check without validating).
  Future<bool> hasTokens() async {
    final token = await getAccessToken();
    return token != null && token.isNotEmpty;
  }

  Future<String?> _readWithNativeFallback(String key) async {
    if (_isWeb()) {
      return _webBackend.read(key);
    }

    try {
      final secureValue = await _secureBackend.read(key);
      if (secureValue != null && secureValue.isNotEmpty) {
        return secureValue;
      }
    } catch (error) {
      debugPrint(
        '[TokenStorage] Secure read failed, checking fallback storage: $error',
      );
    }

    return _webBackend.read(key);
  }
}

abstract interface class TokenStorageBackend {
  Future<void> write(String key, String value);
  Future<String?> read(String key);
  Future<void> delete(String key);
}

class _SecureStorageBackend implements TokenStorageBackend {
  const _SecureStorageBackend({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  @override
  Future<void> write(String key, String value) {
    return _storage.write(key: key, value: value);
  }

  @override
  Future<String?> read(String key) {
    return _storage.read(key: key);
  }

  @override
  Future<void> delete(String key) {
    return _storage.delete(key: key);
  }
}

class _SharedPreferencesBackend implements TokenStorageBackend {
  const _SharedPreferencesBackend();

  @override
  Future<void> write(String key, String value) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(key, value);
  }

  @override
  Future<String?> read(String key) async {
    final preferences = await SharedPreferences.getInstance();
    return preferences.getString(key);
  }

  @override
  Future<void> delete(String key) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.remove(key);
  }
}
