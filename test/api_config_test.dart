import 'package:flutter_test/flutter_test.dart';
import 'package:eventhub_mobile/core/api/api_config.dart';

void main() {
  group('ApiConfig Host & BaseUrl Resolution Tests', () {
    test('baseUrl always ends with /api and points to api.eventhub.id.vn', () {
      final base = ApiConfig.baseUrl;
      expect(base, equals('https://api.eventhub.id.vn/api'));
      expect(base, endsWith('/api'));
      expect(base.endsWith('/api/'), isFalse);
      expect(base.startsWith('https://'), isTrue);
    });

    test('apiHost returns fixed host api.eventhub.id.vn', () {
      final host = ApiConfig.apiHost;
      expect(host, equals('api.eventhub.id.vn'));
      expect(host.contains('/'), isFalse);
      expect(host.contains('http://'), isFalse);
      expect(host.contains('https://'), isFalse);
    });

    test('apiPort defaults to 443 for HTTPS', () {
      expect(ApiConfig.apiPort, equals(443));
    });

    test('apiProtocol defaults to https', () {
      expect(ApiConfig.apiProtocol, equals('https'));
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
      expect(fullUrl, equals('https://api.eventhub.id.vn/api/events'));
      expect(fullUrl.contains('/api/api'), isFalse);
      expect(fullUrl.contains('://'), isTrue);
      final withoutProtocol = fullUrl.replaceFirst('https://', '');
      expect(withoutProtocol.contains('//'), isFalse);
    });

    test('Dynamic parameter methods format URLs cleanly', () {
      expect(ApiConfig.ticketDetail('tk-123'), equals('/tickets/tk-123'));
      expect(ApiConfig.ticketDownload('tk-123'), equals('/tickets/tk-123/download'));
      expect(ApiConfig.orderStatus('ord-456'), equals('/orders/ord-456/status'));
      expect(ApiConfig.cancelOrder('ord-456'), equals('/orders/ord-456/cancel'));
      expect(ApiConfig.staffTicketDetail('tk-999'), equals('/staff/tickets/tk-999'));
      expect(ApiConfig.staffCheckInTicket('tk-999'), equals('/staff/tickets/tk-999/check-in'));
      expect(ApiConfig.staffCheckInReport('evt-123'), equals('/operations/staff/check-in-report?event_id=evt-123'));
      expect(ApiConfig.staffCheckInReport(), equals('/operations/staff/check-in-report'));
      expect(ApiConfig.staffDirectBookingStatus('ord-999'), equals('/orders/staff/direct-booking/ord-999/status'));
    });
  });
}
