import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Secure token storage for authentication tokens.
///
/// Uses [SharedPreferences] for token persistence. On web this maps to
/// localStorage; on native platforms it uses the platform key-value store.
/// For production, swap to flutter_secure_storage with proper code signing.
class TokenStorage {
  TokenStorage._();

  static final TokenStorage instance = TokenStorage._();

  static const _accessTokenKey = 'vio_access_token';
  static const _refreshTokenKey = 'vio_refresh_token';

  /// Save both access and refresh tokens.
  Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_accessTokenKey, accessToken);
    await prefs.setString(_refreshTokenKey, refreshToken);
    debugPrint('[TokenStorage] Tokens saved');
  }

  /// Get the stored access token, or null if not set.
  Future<String?> getAccessToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_accessTokenKey);
  }

  /// Get the stored refresh token, or null if not set.
  Future<String?> getRefreshToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_refreshTokenKey);
  }

  /// Clear all stored tokens (logout).
  Future<void> clearTokens() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_accessTokenKey);
    await prefs.remove(_refreshTokenKey);
    debugPrint('[TokenStorage] Tokens cleared');
  }

  /// Check whether tokens are stored (quick check without validating).
  Future<bool> hasTokens() async {
    final t = await getAccessToken();
    return t != null && t.isNotEmpty;
  }
}
