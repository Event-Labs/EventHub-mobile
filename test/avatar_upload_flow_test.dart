import 'package:flutter_test/flutter_test.dart';
import 'package:eventhub_mobile/core/models/user_model.dart';

void main() {
  group('Avatar Upload & Profile Update Tests', () {
    test('UserModel updates avatarUrl cleanly with copyWith', () {
      final user = UserModel(
        id: 'u-1',
        email: 'user@eventhub.vn',
        fullName: 'Nguyễn Văn Test',
        role: 'CUSTOMER',
        avatarUrl: null,
      );

      expect(user.avatarUrl, isNull);

      const newUploadedUrl = 'https://res.cloudinary.com/eventhub/image/upload/v12345/avatar_u-1.jpg';
      final updated = user.copyWith(avatarUrl: newUploadedUrl);

      expect(updated.avatarUrl, equals(newUploadedUrl));
      expect(updated.id, equals('u-1'));
      expect(updated.fullName, equals('Nguyễn Văn Test'));
      expect(user.avatarUrl, isNull); // Immutability verified
    });

    test('UserModel toJson and fromJson preserves avatarUrl', () {
      const avatar = 'https://res.cloudinary.com/eventhub/avatar.png';
      final user = UserModel(
        id: 'u-2',
        email: 'test2@eventhub.vn',
        fullName: 'Lê Thị B',
        role: 'STAFF',
        avatarUrl: avatar,
      );

      final json = user.toJson();
      expect(json['avatar_url'], equals(avatar));

      final restored = UserModel.fromJson(json);
      expect(restored.avatarUrl, equals(avatar));
      expect(restored.role, equals('STAFF'));
    });
  });
}

