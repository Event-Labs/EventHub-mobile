import 'package:flutter_test/flutter_test.dart';
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
      final checkInTimestamp = '2026-10-21T09:30:00.000Z';
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
      final nowStr = '2026-10-21T16:50:00.000Z';
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
  });
}
