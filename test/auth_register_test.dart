import 'package:flutter_test/flutter_test.dart';

bool validateEmail(String email) {
  final emailRegex = RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$');
  return emailRegex.hasMatch(email.trim());
}

bool validatePassword(String password) {
  if (password.length < 8) return false;
  if (!password.contains(RegExp(r'[A-Z]'))) return false;
  if (!password.contains(RegExp(r'[a-z]'))) return false;
  if (!password.contains(RegExp(r'[0-9]'))) return false;
  if (!password.contains(RegExp(r'[^a-zA-Z0-9]'))) return false;
  return true;
}

bool validatePhone(String? phone) {
  if (phone == null || phone.trim().isEmpty) return true; // optional
  return RegExp(r'^[0-9]{9,11}$').hasMatch(phone.trim());
}

void main() {
  group('Register Form Validation Tests', () {
    test('Email format validator', () {
      expect(validateEmail('test@eventhub.vn'), isTrue);
      expect(validateEmail('user.name+tag@sub.domain.com'), isTrue);
      expect(validateEmail('invalid-email'), isFalse);
      expect(validateEmail('invalid@'), isFalse);
      expect(validateEmail('@domain.com'), isFalse);
      expect(validateEmail('test@domain'), isFalse);
    });

    test('Password complexity requirements (aligns with backend Zod schema)', () {
      // Valid password
      expect(validatePassword('Admin@123'), isTrue);
      expect(validatePassword('Secret!2026'), isTrue);
      expect(validatePassword('P@ssw0rd#Event'), isTrue);

      // Too short (< 8 chars)
      expect(validatePassword('Abc!1'), isFalse);

      // Missing uppercase
      expect(validatePassword('password@123'), isFalse);

      // Missing lowercase
      expect(validatePassword('PASSWORD@123'), isFalse);

      // Missing number
      expect(validatePassword('Password@Special'), isFalse);

      // Missing special character
      expect(validatePassword('Password123'), isFalse);
    });

    test('Phone number validator (optional but must be 9-11 digits if given)', () {
      expect(validatePhone(null), isTrue);
      expect(validatePhone(''), isTrue);
      expect(validatePhone('   '), isTrue);
      expect(validatePhone('0987654321'), isTrue);
      expect(validatePhone('01234567890'), isTrue);
      expect(validatePhone('12345'), isFalse); // too short
      expect(validatePhone('0987654321012'), isFalse); // too long
      expect(validatePhone('09876abcde'), isFalse); // non-digits
    });
  });
}
