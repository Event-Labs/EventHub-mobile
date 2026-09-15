import 'package:flutter_test/flutter_test.dart';
import 'package:eventhub_mobile/core/api/api_config.dart';
import 'package:eventhub_mobile/core/api/auth_service.dart';

void main() {
  group('Google Login Config & Auth Tests', () {
    test('ApiConfig has correct Google login endpoint and serverClientId', () {
      expect(ApiConfig.googleLogin, equals('/auth/google'));
      expect(ApiConfig.googleServerClientId, isNotEmpty);
      expect(ApiConfig.googleServerClientId, contains('.apps.googleusercontent.com'));
    });

    test('AuthService initial state isLoggedIn is false before login', () {
      final authService = AuthService();
      expect(authService.currentUser, isNull);
      expect(authService.isLoggedIn, isFalse);
    });
  });
}
