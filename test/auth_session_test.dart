import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:eventhub_mobile/core/models/user_model.dart';
import 'package:eventhub_mobile/core/api/auth_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Auth Session & Role Navigation Tests', () {
    test('Staff user session correctly identifies canAccessStaff = true', () async {
      final staffUser = UserModel(
        id: 'user-staff-1',
        email: 'staff@eventhub.vn',
        fullName: 'Nhân Viên Soát Vé',
        role: 'STAFF',
        roles: ['STAFF'],
      );

      SharedPreferences.setMockInitialValues({
        'auth_token': 'fake-staff-jwt-token',
        'user_data': jsonEncode(staffUser.toJson()),
      });

      final auth = AuthService();
      final restored = await auth.restoreSession();

      expect(restored, isNotNull);
      expect(restored!.id, equals('user-staff-1'));
      expect(restored.canAccessStaff, isTrue);
      expect(restored.role, equals('STAFF'));
    });

    test('Customer user session correctly identifies canAccessStaff = false', () async {
      final customerUser = UserModel(
        id: 'user-cust-1',
        email: 'customer@eventhub.vn',
        fullName: 'Khách Mua Vé',
        role: 'CUSTOMER',
        roles: ['CUSTOMER'],
      );

      SharedPreferences.setMockInitialValues({
        'auth_token': 'fake-cust-jwt-token',
        'user_data': jsonEncode(customerUser.toJson()),
      });

      final auth = AuthService();
      final restored = await auth.restoreSession();

      expect(restored, isNotNull);
      expect(restored!.id, equals('user-cust-1'));
      expect(restored.canAccessStaff, isFalse);
      expect(restored.role, equals('CUSTOMER'));
    });

    test('Logout clears session from SharedPreferences and currentUser becomes null', () async {
      SharedPreferences.setMockInitialValues({
        'auth_token': 'fake-jwt-token',
        'user_data': jsonEncode({'id': 'user-1', 'email': 'test@test.com', 'role': 'CUSTOMER'}),
      });

      final auth = AuthService();
      await auth.logout();

      expect(auth.currentUser, isNull);
      expect(auth.isLoggedIn, isFalse);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('auth_token'), isNull);
      expect(prefs.getString('user_data'), isNull);
    });
  });
}

