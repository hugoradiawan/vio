import 'package:flutter_test/flutter_test.dart';
import 'package:vio_client/src/core/auth/token_storage.dart';

class _InMemoryBackend implements TokenStorageBackend {
  final Map<String, String> values = <String, String>{};
  int writes = 0;
  int reads = 0;
  int deletes = 0;

  @override
  Future<void> delete(String key) async {
    deletes += 1;
    values.remove(key);
  }

  @override
  Future<String?> read(String key) async {
    reads += 1;
    return values[key];
  }

  @override
  Future<void> write(String key, String value) async {
    writes += 1;
    values[key] = value;
  }
}

class _ThrowingBackend implements TokenStorageBackend {
  @override
  Future<void> delete(String key) async {
    throw Exception('delete failed');
  }

  @override
  Future<String?> read(String key) async {
    throw Exception('read failed');
  }

  @override
  Future<void> write(String key, String value) async {
    throw Exception('write failed');
  }
}

void main() {
  group('TokenStorage', () {
    test('uses secure backend on native platforms', () async {
      final secureBackend = _InMemoryBackend();
      final webBackend = _InMemoryBackend();
      final storage = TokenStorage.forTesting(
        secureBackend: secureBackend,
        webBackend: webBackend,
        webChecker: () => false,
      );

      await storage.saveTokens(
        accessToken: 'native-access',
        refreshToken: 'native-refresh',
      );

      expect(await storage.getAccessToken(), 'native-access');
      expect(await storage.getRefreshToken(), 'native-refresh');
      expect(secureBackend.writes, 2);
      expect(webBackend.writes, 0);
    });

    test('uses web backend when running on web', () async {
      final secureBackend = _InMemoryBackend();
      final webBackend = _InMemoryBackend();
      final storage = TokenStorage.forTesting(
        secureBackend: secureBackend,
        webBackend: webBackend,
        webChecker: () => true,
      );

      await storage.saveTokens(
        accessToken: 'web-access',
        refreshToken: 'web-refresh',
      );

      expect(await storage.getAccessToken(), 'web-access');
      expect(await storage.getRefreshToken(), 'web-refresh');
      expect(webBackend.writes, 2);
      expect(secureBackend.writes, 0);
    });

    test('clearTokens removes both token keys', () async {
      final secureBackend = _InMemoryBackend();
      final webBackend = _InMemoryBackend();
      final storage = TokenStorage.forTesting(
        secureBackend: secureBackend,
        webBackend: webBackend,
        webChecker: () => false,
      );

      await storage.saveTokens(accessToken: 'a', refreshToken: 'r');
      await storage.clearTokens();

      expect(await storage.getAccessToken(), isNull);
      expect(await storage.getRefreshToken(), isNull);
      expect(secureBackend.deletes, 2);
      expect(webBackend.deletes, 2);
    });

    test('hasTokens is true only when access token is present and non-empty',
        () async {
      final backend = _InMemoryBackend();
      final storage = TokenStorage.forTesting(
        secureBackend: backend,
        webBackend: backend,
        webChecker: () => false,
      );

      expect(await storage.hasTokens(), isFalse);

      await storage.saveTokens(accessToken: '', refreshToken: 'r');
      expect(await storage.hasTokens(), isFalse);

      await storage.saveTokens(accessToken: 'access', refreshToken: 'r2');
      expect(await storage.hasTokens(), isTrue);
    });

    test('falls back to web backend when secure write fails on native',
        () async {
      final secureBackend = _ThrowingBackend();
      final webBackend = _InMemoryBackend();
      final storage = TokenStorage.forTesting(
        secureBackend: secureBackend,
        webBackend: webBackend,
        webChecker: () => false,
      );

      await storage.saveTokens(
        accessToken: 'access-fallback',
        refreshToken: 'refresh-fallback',
      );

      expect(await storage.getAccessToken(), 'access-fallback');
      expect(await storage.getRefreshToken(), 'refresh-fallback');
      expect(webBackend.writes, 2);
    });

    test('falls back to web backend when secure read fails on native',
        () async {
      final secureBackend = _ThrowingBackend();
      final webBackend = _InMemoryBackend()
        ..values['vio_access_token'] = 'persisted-access';
      final storage = TokenStorage.forTesting(
        secureBackend: secureBackend,
        webBackend: webBackend,
        webChecker: () => false,
      );

      expect(await storage.getAccessToken(), 'persisted-access');
    });
  });
}
