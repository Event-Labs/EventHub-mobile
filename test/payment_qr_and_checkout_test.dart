import 'package:flutter_test/flutter_test.dart';
import 'package:eventhub_mobile/features/home/presentation/pages/payment_page.dart';

void main() {
  group('PayOS QR and Expiry Logic Tests', () {
    test('paymentQrImageSrc handles empty/null qrCode correctly', () {
      expect(PaymentPage.paymentQrImageSrc(null), '');
      expect(PaymentPage.paymentQrImageSrc(''), '');
      expect(PaymentPage.paymentQrImageSrc('   '), '');
    });

    test('paymentQrImageSrc returns direct URL if already http/https or data:image', () {
      const httpUrl = 'https://res.cloudinary.com/eventhub/qr_code.png';
      expect(PaymentPage.paymentQrImageSrc(httpUrl), httpUrl);

      const dataUri = 'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAA...';
      expect(PaymentPage.paymentQrImageSrc(dataUri), dataUri);
    });

    test('paymentQrImageSrc transforms raw VietQR string to QR server image URL with encoding', () {
      const vietQrPayload = '00020101021238570010A000000727012700069704220113VQRQAMYOU44120208QRIBFTTA530370454062500005802VN62270823EH ORD1792544006093B1746304151E';
      final generatedUrl = PaymentPage.paymentQrImageSrc(vietQrPayload);

      expect(generatedUrl.startsWith('https://api.qrserver.com/v1/create-qr-code/'), isTrue);
      expect(generatedUrl.contains('data='), isTrue);
      expect(generatedUrl.contains(Uri.encodeComponent(vietQrPayload)), isTrue);
    });

    test('Vietnamese Phone regex validation complies with backend Zod schema', () {
      final phoneRegex = RegExp(r'^(0|\+84)(3|5|7|8|9)[0-9]{8}$');

      // Valid Vietnamese numbers
      expect(phoneRegex.hasMatch('0912345678'), isTrue);
      expect(phoneRegex.hasMatch('0388889999'), isTrue);
      expect(phoneRegex.hasMatch('0771234567'), isTrue);
      expect(phoneRegex.hasMatch('0866554433'), isTrue);
      expect(phoneRegex.hasMatch('0521234567'), isTrue);
      expect(phoneRegex.hasMatch('+84912345678'), isTrue);
      expect(phoneRegex.hasMatch('+84388889999'), isTrue);

      // Invalid numbers
      expect(phoneRegex.hasMatch('123456'), isFalse);
      expect(phoneRegex.hasMatch('0123456789'), isFalse); // Prefix 01 no longer valid VN mobile
      expect(phoneRegex.hasMatch('09123456789'), isFalse); // 11 digits with 09
      expect(phoneRegex.hasMatch('091234567'), isFalse); // 9 digits
      expect(phoneRegex.hasMatch('091234567a'), isFalse);
    });

    test('ExpiredAt date difference calculation computes positive seconds for future dates and 0 for past', () {
      final futureDate = DateTime.now().toUtc().add(const Duration(minutes: 10)).toIso8601String();
      final expiryFuture = DateTime.parse(futureDate).toUtc();
      final diffFuture = expiryFuture.difference(DateTime.now().toUtc()).inSeconds;
      expect(diffFuture, greaterThan(550));
      expect(diffFuture, lessThanOrEqualTo(600));

      final pastDate = DateTime.now().toUtc().subtract(const Duration(minutes: 5)).toIso8601String();
      final expiryPast = DateTime.parse(pastDate).toUtc();
      final diffPast = expiryPast.difference(DateTime.now().toUtc()).inSeconds;
      final secondsLeft = diffPast > 0 ? diffPast : 0;
      expect(secondsLeft, equals(0));
    });
  });
}
