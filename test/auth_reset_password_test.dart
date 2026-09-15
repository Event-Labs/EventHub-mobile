import 'package:flutter_test/flutter_test.dart';
import 'package:eventhub_mobile/core/api/api_config.dart';

String extractResetToken(String input) {
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

bool validateResetPassword(String password) {
  if (password.length < 8) return false;
  if (!password.contains(RegExp(r'[A-Z]'))) return false;
  if (!password.contains(RegExp(r'[a-z]'))) return false;
  if (!password.contains(RegExp(r'[0-9]'))) return false;
  if (!password.contains(RegExp(r'[^a-zA-Z0-9]'))) return false;
  return true;
}

void main() {
  group('Reset Password Token Extraction & Password Validation Tests', () {
    test('ApiConfig has forgotPassword and resetPassword endpoints', () {
      expect(ApiConfig.forgotPassword, equals('/auth/forgot-password'));
      expect(ApiConfig.resetPassword, equals('/auth/reset-password'));
    });

    test('extractResetToken handles raw reset token string', () {
      const raw = 'f4a7c8e9b0123456789abcdef0123456';
      expect(extractResetToken(raw), equals(raw));
      expect(extractResetToken('   $raw   '), equals(raw));
    });

    test('extractResetToken extracts from Web URL', () {
      const url = 'http://localhost:5173/reset-password?token=f4a7c8e9b0123456789abcdef0123456';
      expect(extractResetToken(url), equals('f4a7c8e9b0123456789abcdef0123456'));
    });

    test('extractResetToken extracts from Mobile Deep Link URL', () {
      const deepLink = 'eventhub://reset-password?token=f4a7c8e9b0123456789abcdef0123456';
      expect(extractResetToken(deepLink), equals('f4a7c8e9b0123456789abcdef0123456'));
    });

    test('validateResetPassword complies with backend Zod rules', () {
      expect(validateResetPassword('NewPassword@2026'), isTrue);
      expect(validateResetPassword('short!1'), isFalse);
      expect(validateResetPassword('lowercaseonly!1'), isFalse);
      expect(validateResetPassword('UPPERCASEONLY!1'), isFalse);
      expect(validateResetPassword('NoNumberSpecial!'), isFalse);
      expect(validateResetPassword('NoSpecialChar123'), isFalse);
    });
  });
}
