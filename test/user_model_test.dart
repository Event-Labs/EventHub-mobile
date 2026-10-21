import 'package:flutter_test/flutter_test.dart';
import 'package:eventhub_mobile/core/models/user_model.dart';

void main() {
  group('UserModel DOB tests', () {
    test('parseDob handles YYYY-MM-DD directly', () {
      expect(UserModel.parseDob('2004-01-06'), '2004-01-06');
    });

    test('parseDob handles ISO UTC date string', () {
      final parsed = UserModel.parseDob('2004-01-05T17:00:00.000Z');
      expect(parsed, isNotNull);
      final dt = DateTime.parse('2004-01-05T17:00:00.000Z').toLocal();
      final expected = "${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}";
      expect(parsed, expected);
    });

    test('formattedDob outputs dd/MM/yyyy format', () {
      final user = UserModel(
        id: '1',
        email: 'test@example.com',
        fullName: 'Test User',
        role: 'CUSTOMER',
        dob: '2004-01-06',
      );
      expect(user.formattedDob, '06/01/2004');
    });

    test('formattedDob outputs Chưa cập nhật when dob is null or empty', () {
      final user = UserModel(
        id: '1',
        email: 'test@example.com',
        fullName: 'Test User',
        role: 'CUSTOMER',
        dob: null,
      );
      expect(user.formattedDob, 'Chưa cập nhật');
    });
  });

  group('UserModel Roles & Authorization tests', () {
    test('Resolves dual role when roles has CUSTOMER and STAFF', () {
      final json = {
        'id': 'user-1',
        'email': 'staff@example.com',
        'full_name': 'Staff User',
        'roles': ['CUSTOMER', 'STAFF'],
      };
      final user = UserModel.fromJson(json);
      expect(user.role, 'STAFF');
      expect(user.isStaff, isTrue);
      expect(user.isCustomer, isTrue);
      expect(user.isCustomerOnly, isFalse);
      expect(user.canSwitchRoles, isTrue);
      expect(user.canAccessStaff, isTrue);
      expect(user.hasRole('STAFF'), isTrue);
      expect(user.hasRole('CUSTOMER'), isTrue);
      expect(user.roleDisplayName, 'Khách hàng & Nhân viên');
    });

    test('Resolves ORGANIZER priority when roles has CUSTOMER and ORGANIZER', () {
      final json = {
        'id': 'user-2',
        'email': 'org@example.com',
        'full_name': 'Organizer User',
        'roles': ['CUSTOMER', 'ORGANIZER'],
      };
      final user = UserModel.fromJson(json);
      expect(user.role, 'ORGANIZER');
      expect(user.isOrganizer, isTrue);
      expect(user.isStaff, isFalse);
      expect(user.canAccessStaff, isFalse);
      expect(user.roleDisplayName, 'Ban tổ chức');
    });

    test('Resolves ADMIN priority when roles has ADMIN', () {
      final json = {
        'id': 'user-3',
        'email': 'admin@example.com',
        'full_name': 'Admin User',
        'roles': ['CUSTOMER', 'ADMIN'],
      };
      final user = UserModel.fromJson(json);
      expect(user.role, 'ADMIN');
      expect(user.isAdmin, isTrue);
      expect(user.hasRole('STAFF'), isFalse);
      expect(user.roleDisplayName, 'Quản trị viên');
    });

    test('Resolves CUSTOMER when user only has CUSTOMER role', () {
      final json = {
        'id': 'user-4',
        'email': 'cust@example.com',
        'full_name': 'Customer User',
        'roles': ['CUSTOMER'],
      };
      final user = UserModel.fromJson(json);
      expect(user.role, 'CUSTOMER');
      expect(user.isStaff, isFalse);
      expect(user.isCustomer, isTrue);
      expect(user.isCustomerOnly, isTrue);
      expect(user.canSwitchRoles, isFalse);
      expect(user.canAccessStaff, isFalse);
      expect(user.hasRole('STAFF'), isFalse);
      expect(user.roleDisplayName, 'Khách hàng');
    });
  });
}
