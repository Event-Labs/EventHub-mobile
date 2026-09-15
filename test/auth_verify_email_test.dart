import 'package:flutter_test/flutter_test.dart';
import 'package:eventhub_mobile/core/api/api_config.dart';

String extractToken(String input) {
  final trimmed = input.trim();
  if (trimmed.contains('token=')) {
    try {
      final uri = Uri.parse(trimmed);
      final token = uri.queryParameters['token'];
      if (token != null && token.isNotEmpty) {
        return token;
      }
    } catch (_) {}
    final split = trimmed.split('token=');
    if (split.length > 1) {
      return split[1].split('&').first.trim();
    }
  }
  return trimmed;
}

void main() {
  group('Verify Email Token Extraction & Config Tests', () {
    test('ApiConfig has verifyEmail endpoint', () {
      expect(ApiConfig.verifyEmail, equals('/auth/verify-email'));
    });

    test('extractToken handles raw token string', () {
      const raw = '8d90f7a2139b4f2c0192eab82910cdfa';
      expect(extractToken(raw), equals(raw));
      expect(extractToken('   $raw   '), equals(raw));
    });

    test('extractToken extracts from Web URL', () {
      const url = 'http://localhost:5173/verify-email?token=8d90f7a2139b4f2c0192eab82910cdfa';
      expect(extractToken(url), equals('8d90f7a2139b4f2c0192eab82910cdfa'));
    });

    test('extractToken extracts from Mobile Deep Link URL', () {
      const deepLink = 'eventhub://verify-email?token=8d90f7a2139b4f2c0192eab82910cdfa';
      expect(extractToken(deepLink), equals('8d90f7a2139b4f2c0192eab82910cdfa'));
    });

    test('extractToken handles URL with additional query parameters', () {
      const multiParam = 'eventhub://verify-email?source=app&token=secret_token_123&utm_medium=email';
      expect(extractToken(multiParam), equals('secret_token_123'));
    });
  });
}
