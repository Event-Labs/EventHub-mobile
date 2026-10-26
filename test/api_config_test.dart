import 'package:flutter_test/flutter_test.dart';
import 'package:eventhub_mobile/core/api/api_config.dart';

void main() {
  group('ApiConfig Host & BaseUrl Resolution Tests', () {
    test('baseUrl always ends with /api and does not have trailing slash', () {
      final base = ApiConfig.baseUrl;
      expect(base, endsWith('/api'));
      expect(base.endsWith('/api/'), isFalse);
      expect(base.startsWith('http://') || base.startsWith('https://'), isTrue);
    });

    test('apiHost returns valid non-empty host', () {
      final host = ApiConfig.apiHost;
      expect(host, isNotEmpty);
      expect(host.contains('/'), isFalse);
      expect(host.contains('http://'), isFalse);
      expect(host.contains('https://'), isFalse);
    });

    test('apiPort defaults to 3000', () {
      expect(ApiConfig.apiPort, equals(3000));
    });

    test('apiProtocol defaults to http', () {
      expect(ApiConfig.apiProtocol, equals('http'));
    });

    test('Core API endpoints are properly formatted with leading slashes', () {
      expect(ApiConfig.login, startsWith('/'));
      expect(ApiConfig.register, startsWith('/'));
      expect(ApiConfig.events, startsWith('/'));
      expect(ApiConfig.categories, startsWith('/'));
      expect(ApiConfig.orders, startsWith('/'));
      expect(ApiConfig.checkout, startsWith('/'));
      expect(ApiConfig.myTickets, startsWith('/'));
      expect(ApiConfig.staffAssignedEvents, startsWith('/'));
      expect(ApiConfig.staffSearchTickets, startsWith('/'));
      expect(ApiConfig.staffCheckInQr, startsWith('/'));
      expect(ApiConfig.staffVerifyQr, startsWith('/'));
      expect(ApiConfig.staffDirectBooking, startsWith('/'));
    });

    test('Constructed endpoint URLs do not create duplicate /api/api or double slashes', () {
      final base = ApiConfig.baseUrl;
      final fullUrl = '$base${ApiConfig.events}';
      expect(fullUrl, contains('/api/events'));
      expect(fullUrl.contains('/api/api'), isFalse);
      expect(fullUrl.contains('://'), isTrue);
      // Remove protocol and verify no '//'
      final withoutProtocol = fullUrl.replaceFirst('http://', '').replaceFirst('https://', '');
      expect(withoutProtocol.contains('//'), isFalse);
    });

    test('Dynamic parameter methods format URLs cleanly', () {
      expect(ApiConfig.ticketDetail('tk-123'), equals('/tickets/tk-123'));
      expect(ApiConfig.ticketDownload('tk-123'), equals('/tickets/tk-123/download'));
      expect(ApiConfig.orderStatus('ord-456'), equals('/orders/ord-456/status'));
      expect(ApiConfig.cancelOrder('ord-456'), equals('/orders/ord-456/cancel'));
      expect(ApiConfig.staffTicketDetail('tk-999'), equals('/staff/tickets/tk-999'));
      expect(ApiConfig.staffCheckInTicket('tk-999'), equals('/staff/tickets/tk-999/check-in'));
      expect(ApiConfig.staffDirectBookingStatus('ord-999'), equals('/orders/staff/direct-booking/ord-999/status'));
    });
  });
}
