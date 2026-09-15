import 'package:flutter_test/flutter_test.dart';
import 'package:eventhub_mobile/core/models/user_model.dart';

String? validateCurrentPassword(String? val, bool hasPassword) {
  if (!hasPassword) return null;
  if (val == null || val.trim().isEmpty) {
    return 'Vui lòng nhập mật khẩu hiện tại';
  }
  return null;
}

String? validateNewPassword({
  required String? val,
  required String? currentPassword,
  required bool hasPassword,
}) {
  if (val == null || val.isEmpty) {
    return 'Vui lòng nhập mật khẩu mới';
  }
  if (val.length < 8 ||
      !val.contains(RegExp(r'[A-Z]')) ||
      !val.contains(RegExp(r'[a-z]')) ||
      !val.contains(RegExp(r'[0-9]')) ||
      !val.contains(RegExp(r'[^a-zA-Z0-9]'))) {
    return 'Mật khẩu từ 8 ký tự, gồm ít nhất 1 chữ hoa, 1 thường, 1 số và 1 ký tự đặc biệt';
  }
  if (hasPassword && currentPassword != null && val.trim() == currentPassword.trim()) {
    return 'Mật khẩu mới không được trùng với mật khẩu hiện tại';
  }
  return null;
}

String? validateConfirmPassword(String? val, String? newPassword) {
  if (val == null || val != newPassword) {
    return 'Mật khẩu xác nhận không trùng khớp';
  }
  return null;
}

void main() {
  group('Change Password Validation & UserModel Tests', () {
    test('validateCurrentPassword requires password if hasPassword is true', () {
      expect(validateCurrentPassword('', true), equals('Vui lòng nhập mật khẩu hiện tại'));
      expect(validateCurrentPassword(null, true), equals('Vui lòng nhập mật khẩu hiện tại'));
      expect(validateCurrentPassword('   ', true), equals('Vui lòng nhập mật khẩu hiện tại'));
      expect(validateCurrentPassword('OldPassword@123', true), isNull);
    });

    test('validateCurrentPassword allows empty if hasPassword is false (Google OAuth)', () {
      expect(validateCurrentPassword('', false), isNull);
      expect(validateCurrentPassword(null, false), isNull);
    });

    test('validateNewPassword enforces strong password criteria', () {
      expect(
        validateNewPassword(val: 'Pass@1', currentPassword: 'Old@1234', hasPassword: true),
        equals('Mật khẩu từ 8 ký tự, gồm ít nhất 1 chữ hoa, 1 thường, 1 số và 1 ký tự đặc biệt'),
      );
      expect(
        validateNewPassword(val: 'nouppercase@123', currentPassword: 'Old@1234', hasPassword: true),
        isNotNull,
      );
      expect(
        validateNewPassword(val: 'NOLOWERCASE@123', currentPassword: 'Old@1234', hasPassword: true),
        isNotNull,
      );
      expect(
        validateNewPassword(val: 'NoSpecialDigitWord', currentPassword: 'Old@1234', hasPassword: true),
        isNotNull,
      );
      expect(
        validateNewPassword(val: 'NewValidPassword@2026', currentPassword: 'Old@1234', hasPassword: true),
        isNull,
      );
    });

    test('validateNewPassword rejects if new password is identical to current password', () {
      expect(
        validateNewPassword(val: 'OldPassword@2026', currentPassword: 'OldPassword@2026', hasPassword: true),
        equals('Mật khẩu mới không được trùng với mật khẩu hiện tại'),
      );
    });

    test('validateConfirmPassword checks equality with new password', () {
      expect(validateConfirmPassword('MatchPass@123', 'MatchPass@123'), isNull);
      expect(
        validateConfirmPassword('MismatchPass@123', 'MatchPass@123'),
        equals('Mật khẩu xác nhận không trùng khớp'),
      );
      expect(validateConfirmPassword(null, 'MatchPass@123'), isNotNull);
    });

    test('UserModel hasPassword is true by default and can be toggled via copyWith', () {
      final user = UserModel(
        id: 'u-1',
        email: 'test@example.com',
        fullName: 'Test User',
        role: 'CUSTOMER',
        hasPassword: false,
      );
      expect(user.hasPassword, isFalse);

      final updated = user.copyWith(hasPassword: true);
      expect(updated.hasPassword, isTrue);
      expect(updated.id, equals('u-1'));
    });
  });
}
