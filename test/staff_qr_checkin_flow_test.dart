import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:eventhub_mobile/core/api/staff_service.dart';
import 'package:eventhub_mobile/core/models/ticket_model.dart';

void main() {
  group('Staff QR Verification & Check-in Flow Tests', () {
    test('Unused valid ticket is identified for check-in button display', () {
      final ticket = TicketModel.fromJson({
        'id': 'ticket-001',
        'ticket_code': 'TICK-1234',
        'status': 'VALID',
        'attendee_name': 'Nguyễn Văn A',
        'event_title': 'Đêm Nhạc Rock 2026',
        'ticket_type_name': 'VIP',
        'checked_in_at': null,
      });

      expect(ticket.isUsed, isFalse);
      expect(ticket.isValid, isTrue);
      expect(ticket.checkInTime, isNull);
      expect(ticket.ticketCode, equals('TICK-1234'));
      expect(ticket.customerName, equals('Nguyễn Văn A'));
    });

    test('Already checked-in ticket is identified to hide button and display check-in time', () {
      const checkInTimestamp = '2026-10-21T09:30:00.000Z';
      final ticket = TicketModel.fromJson({
        'id': 'ticket-002',
        'ticket_code': 'TICK-5678',
        'status': 'USED',
        'attendee_name': 'Trần Thị B',
        'event_title': 'Hội thảo AI & IoT',
        'ticket_type_name': 'Standard',
        'checked_in_at': checkInTimestamp,
      });

      expect(ticket.isUsed, isTrue);
      expect(ticket.isValid, isFalse);
      expect(ticket.checkInTime, equals(checkInTimestamp));
      expect(ticket.formattedCheckInTime, contains('21/10/2026'));
      expect(ticket.formattedStatus, equals('Đã dùng'));
    });

    test('Ticket transitions from unchecked to checked-in using copyWith', () {
      final ticket = TicketModel.fromJson({
        'id': 'ticket-003',
        'ticket_code': 'TICK-9999',
        'status': 'VALID',
        'attendee_name': 'Lê Văn C',
        'event_title': 'Lễ hội Âm nhạc EDM',
        'ticket_type_name': 'GA',
        'checked_in_at': null,
      });

      expect(ticket.isUsed, isFalse);
      expect(ticket.isValid, isTrue);

      // Staff presses check-in button -> ticket is updated
      const nowStr = '2026-10-21T16:50:00.000Z';
      final updatedTicket = ticket.copyWith(
        status: 'USED',
        checkInTime: nowStr,
      );

      expect(updatedTicket.isUsed, isTrue);
      expect(updatedTicket.isValid, isFalse);
      expect(updatedTicket.status, equals('USED'));
      expect(updatedTicket.checkInTime, equals(nowStr));
      expect(updatedTicket.formattedCheckInTime, contains('21/10/2026'));
      // Immutability check: original ticket is unchanged
      expect(ticket.isUsed, isFalse);
    });

    test('Cancelled, expired, or refunded tickets are not valid for check-in button', () {
      final cancelledTicket = TicketModel.fromJson({
        'id': 'ticket-004',
        'ticket_code': 'TICK-CANCELLED',
        'status': 'CANCELLED',
        'attendee_name': 'Phạm Văn D',
      });
      final expiredTicket = TicketModel.fromJson({
        'id': 'ticket-005',
        'ticket_code': 'TICK-EXPIRED',
        'status': 'EXPIRED',
        'attendee_name': 'Hoàng Thị E',
      });
      final refundedTicket = TicketModel.fromJson({
        'id': 'ticket-006',
        'ticket_code': 'TICK-REFUNDED',
        'status': 'REFUNDED',
        'attendee_name': 'Đặng Văn F',
      });

      expect(cancelledTicket.isValid, isFalse);
      expect(expiredTicket.isValid, isFalse);
      expect(refundedTicket.isValid, isFalse);
      expect(cancelledTicket.formattedStatus, equals('Đã hủy'));
      expect(expiredTicket.formattedStatus, equals('Hết hạn'));
      expect(refundedTicket.formattedStatus, equals('Đã hoàn'));
    });

    test('StaffService.sanitizeStaffMessage preserves meaningful backend Vietnamese messages', () {
      expect(
        StaffService.sanitizeStaffMessage('Vé này chưa đến giờ tham gia.'),
        equals('Vé này chưa đến giờ tham gia.'),
      );
      expect(
        StaffService.sanitizeStaffMessage('Staff không có quyền check-in vé này.'),
        equals('Staff không có quyền check-in vé này.'),
      );
      expect(
        StaffService.sanitizeStaffMessage('Nhân viên không được phân công cho sự kiện này.'),
        equals('Nhân viên không được phân công cho sự kiện này.'),
      );
      expect(
        StaffService.sanitizeStaffMessage('Vé đã được check-in trước đó lúc 14:25:30.'),
        equals('Vé đã được check-in trước đó lúc 14:25:30.'),
      );
      expect(
        StaffService.sanitizeStaffMessage('QR không đúng định dạng vé EventHub.'),
        equals('QR không đúng định dạng vé EventHub.'),
      );
      expect(
        StaffService.sanitizeStaffMessage('QR không khớp sự kiện của vé.'),
        equals('QR không khớp sự kiện của vé.'),
      );
    });

    test('StaffService.sanitizeStaffMessage safely cleans JSON error envelopes', () {
      const jsonMsg = '{"message": "Vé này chưa đến giờ tham gia.", "errorCode": 400}';
      expect(
        StaffService.sanitizeStaffMessage(jsonMsg),
        equals('Vé này chưa đến giờ tham gia.'),
      );
    });

    test('TicketModel parses backend buildStaffTicketPayload shape with nested buyer phone', () {
      final backendPayload = {
        'id': '101',
        'ticket_code': 'TK-PORSCHE-001',
        'qr_code': 'TK-PORSCHE-001',
        'status': 'VALID',
        'attendee_name': 'Bùi Tuấn Khanh',
        'attendee_email': 'khanh@example.com',
        'checked_in_at': null,
        'checked_in_by': null,
        'event': {
          'id': 'evt-porsche',
          'title': 'Không gian trải nghiệm Porsche',
          'slug': 'khong-gian-trai-nghiem-porsche',
          'start_time': '2026-11-10T09:00:00.000Z',
          'end_time': '2026-11-12T18:00:00.000Z',
        },
        'session': {
          'id': 'sess-1',
          'name': 'Phiên sáng 10/11',
          'start_time': '2026-11-10T09:00:00.000Z',
          'end_time': '2026-11-10T12:00:00.000Z',
          'checkin_start_time': '2026-11-10T08:30:00.000Z',
        },
        'ticket_type': {
          'id': 'tt-vip',
          'name': 'Vé Trải Nghiệm VIP',
          'price': 250000,
        },
        'seat': null,
        'order': {
          'id': 'ord-001',
          'order_code': 'ORD-2026-001',
          'status': 'PAID',
          'buyer_name': 'Bùi Tuấn Khanh',
          'buyer_email': 'khanh@example.com',
          'buyer_phone': '0901234567',
        },
        'buyer': {
          'name': 'Bùi Tuấn Khanh',
          'email': 'khanh@example.com',
          'phone': '0901234567',
        },
      };

      final ticket = TicketModel.fromJson(backendPayload);

      expect(ticket.ticketId, equals('101'));
      expect(ticket.ticketCode, equals('TK-PORSCHE-001'));
      expect(ticket.eventName, equals('Không gian trải nghiệm Porsche'));
      expect(ticket.ticketType, equals('Vé Trải Nghiệm VIP'));
      expect(ticket.price, equals(250000));
      expect(ticket.attendeePhone, equals('0901234567'));
      expect(ticket.isValid, isTrue);
      expect(ticket.isUsed, isFalse);
    });

    test('StaffService.parseQrPayload correctly handles BOM, surrounding quotes, and query parameters', () {
      final bomResult = StaffService.parseQrPayload('\uFEFFEH-7A5D992B01');
      expect(bomResult['effective_code'], equals('EH-7A5D992B01'));

      final quotesResult = StaffService.parseQrPayload('"EH-7A5D992B01"');
      expect(quotesResult['effective_code'], equals('EH-7A5D992B01'));

      final urlResult = StaffService.parseQrPayload('https://eventhub.id.vn/staff/check-in?code=EH-7A5D992B01');
      expect(urlResult['effective_code'], equals('EH-7A5D992B01'));

      const jsonStr = '{"type":"EVENTHUB_TICKET","ticket_code":"EH-7A5D992B01","ticket_id":"ticket-1"}';
      final jsonResult = StaffService.parseQrPayload(jsonStr);
      expect(jsonResult['effective_code'], equals('EH-7A5D992B01'));
      expect(jsonResult['ticket_id'], equals('ticket-1'));
      expect(jsonResult['is_valid_type'], equals('true'));
    });

    test('StaffService.parseQrPayload supports Web compact QR types (EHT, EH_TICKET, EH) and rejects invalid type', () {
      final compact = StaffService.parseQrPayload('{"type":"EHT","t":"EH-COMPACT-01"}');
      expect(compact['format'], equals('json'));
      expect(compact['effective_code'], equals('EH-COMPACT-01'));
      expect(compact['ticket_code'], equals('EH-COMPACT-01'));
      expect(compact['is_valid_type'], equals('true'));

      final ehTicket = StaffService.parseQrPayload('{"type":"EH_TICKET","ticketCode":"EH-CAMEL-02","eventId":"evt-1"}');
      expect(ehTicket['effective_code'], equals('EH-CAMEL-02'));
      expect(ehTicket['event_id'], equals('evt-1'));
      expect(ehTicket['is_valid_type'], equals('true'));

      final badType = StaffService.parseQrPayload('{"type":"RANDOM_QR","ticket_code":"EH-BAD-03"}');
      expect(badType['is_valid_type'], equals('false'));
    });

    test('TicketModel.qrPayload generates Web compact JSON format', () {
      final ticket = TicketModel.fromJson({
        'id': 'tk-compact-1',
        'ticket_code': 'EH-COMPACT-999',
        'qr_code': 'EH-COMPACT-999',
        'event_id': 'evt-1',
        'event_session_id': 'sess-1',
        'status': 'VALID',
      });

      final decoded = jsonDecode(ticket.qrPayload) as Map<String, dynamic>;
      expect(decoded, equals({'type': 'EVENTHUB_TICKET', 'ticket_code': 'EH-COMPACT-999'}));
    });

    test('TicketModel handles raw_attendee_name, buyer_phone, checked_in_by, and empty check_in_time safely', () {
      final ticket = TicketModel.fromJson({
        'id': 'tk-web-2',
        'ticket_code': 'EH-WEB-222',
        'status': 'VALID',
        'check_in_status': 'NOT_CHECKED_IN',
        'checked_in_at': null,
        'check_in_time': '',
        'attendee_name': 'Nguyễn Văn B',
        'raw_attendee_name': 'Nguyễn Văn B',
        'raw_attendee_email': 'b@example.com',
        'buyer_name': 'Trần Người Mua',
        'buyer_email': 'buyer@example.com',
        'buyer_phone': '0912345678',
      });

      expect(ticket.isUsed, isFalse);
      expect(ticket.isValid, isTrue);
      expect(ticket.isDifferentAttendee, isTrue);
      expect(ticket.displayPrimaryName, equals('Nguyễn Văn B'));
      expect(ticket.buyerPhone, equals('0912345678'));
      expect(ticket.attendeePhone, equals('0912345678'));
    });

    test('StaffService.sanitizeStaffMessage preserves Web manual check-in subscription guard message', () {
      const msg =
          'Gói dịch vụ của sự kiện này không hỗ trợ tính năng check-in thủ công. Vui lòng quét mã QR hoặc liên hệ Ban tổ chức nâng cấp gói.';
      expect(StaffService.sanitizeStaffMessage(msg), equals(msg));
    });

    test('StaffService.buildSearchPayload aligns filters with Web POST /staff/tickets/search', () {
      expect(
        StaffService.buildSearchPayload(eventId: 'evt-1', query: 'guest@example.com'),
        equals({'eventId': 'evt-1', 'buyerEmail': 'guest@example.com'}),
      );
      expect(
        StaffService.buildSearchPayload(eventId: 'evt-1', query: '090 123 4567'),
        equals({'eventId': 'evt-1', 'buyerPhone': '0901234567'}),
      );
      expect(
        StaffService.buildSearchPayload(
          eventId: 'evt-1',
          query: '{"type":"EVENTHUB_TICKET","ticket_code":"EH-9988"}',
        ),
        equals({'eventId': 'evt-1', 'ticketCode': 'EH-9988'}),
      );
      expect(
        StaffService.buildSearchPayload(eventId: 'evt-1', query: 'Nguyễn Văn An'),
        equals({'eventId': 'evt-1', 'buyerName': 'Nguyễn Văn An'}),
      );
    });

    test('StaffService.normalizeStaffEvent preserves checked_in, total_valid, remaining, and checkin_start_time', () {
      final rawEvent = {
        'id': 'evt-porsche',
        'title': 'Không gian Trải nghiệm Porsche',
        'checked_in': 1,
        'total_valid': 9,
        'remaining': 8,
        'checkin_start_time': '2026-07-22T00:50:00.000Z',
        'gate': 'GATE 01 - Main Entrance',
        'zone': 'Khu vực chính',
        'staff_role': 'Nhân viên soát vé',
      };

      final normalized = StaffService.normalizeStaffEvent(rawEvent);
      expect(normalized['id'], equals('evt-porsche'));
      expect(normalized['checked_in'], equals(1));
      expect(normalized['total_valid'], equals(9));
      expect(normalized['total_tickets'], equals(9));
      expect(normalized['remaining'], equals(8));
      expect(normalized['checkin_start_time'], equals('2026-07-22T00:50:00.000Z'));
    });
  });
}
