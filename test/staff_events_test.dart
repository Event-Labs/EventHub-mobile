import 'package:flutter_test/flutter_test.dart';
import 'package:eventhub_mobile/core/api/staff_service.dart';

void main() {
  group('StaffService checkHasActiveOrUpcomingEvents tests', () {
    final now = DateTime(2026, 9, 15, 12, 0, 0);

    test('Returns false when events list is empty', () {
      final result = StaffService.checkHasActiveOrUpcomingEvents([], referenceTime: now);
      expect(result, isFalse);
    });

    test('Returns false when all events have already ended in the past', () {
      final events = [
        {
          'id': 'e-1',
          'title': 'Concert A',
          'start_time': '2026-09-10T18:00:00.000Z',
          'end_time': '2026-09-10T22:00:00.000Z',
        },
        {
          'id': 'e-2',
          'title': 'Conference B',
          'start_time': '2026-09-14T08:00:00.000Z',
          'end_time': '2026-09-14T17:00:00.000Z',
        },
      ];

      final result = StaffService.checkHasActiveOrUpcomingEvents(events, referenceTime: now);
      expect(result, isFalse);
    });

    test('Returns true when there is an ongoing event', () {
      final events = [
        {
          'id': 'e-1',
          'title': 'Concert Past',
          'start_time': '2026-09-10T18:00:00.000Z',
          'end_time': '2026-09-10T22:00:00.000Z',
        },
        {
          'id': 'e-2',
          'title': 'Ongoing Festival',
          'start_time': '2026-09-15T08:00:00.000Z',
          'end_time': '2026-09-15T18:00:00.000Z',
        },
      ];

      final result = StaffService.checkHasActiveOrUpcomingEvents(events, referenceTime: now);
      expect(result, isTrue);
    });

    test('Returns true when there is an upcoming event', () {
      final events = [
        {
          'id': 'e-1',
          'title': 'Concert Past',
          'start_time': '2026-09-10T18:00:00.000Z',
          'end_time': '2026-09-10T22:00:00.000Z',
        },
        {
          'id': 'e-3',
          'title': 'Upcoming Show',
          'start_time': '2026-09-20T19:00:00.000Z',
          'end_time': '2026-09-20T23:00:00.000Z',
        },
      ];

      final result = StaffService.checkHasActiveOrUpcomingEvents(events, referenceTime: now);
      expect(result, isTrue);
    });

    test('Returns true when event has no end_time but start_time is in the future', () {
      final events = [
        {
          'id': 'e-4',
          'title': 'Future Talk',
          'start_time': '2026-09-25T14:00:00.000Z',
          'end_time': null,
        },
      ];

      final result = StaffService.checkHasActiveOrUpcomingEvents(events, referenceTime: now);
      expect(result, isTrue);
    });

    test('Returns false when event has no end_time and start_time is in the past', () {
      final events = [
        {
          'id': 'e-5',
          'title': 'Past Talk',
          'start_time': '2026-09-01T14:00:00.000Z',
          'end_time': null,
        },
      ];

      final result = StaffService.checkHasActiveOrUpcomingEvents(events, referenceTime: now);
      expect(result, isFalse);
    });

    test('searchTickets returns empty list when backend is not reached, no mock data leakage', () async {
      final tickets = await StaffService().searchTickets('nonexistent_user_query');
      expect(tickets, isEmpty);
    });
  });

  group('Staff direct booking payload formatting tests', () {
    test('Seated event creates items grouped by ticket type with session_seat_ids', () {
      final selectedSeatIds = ['seat-1', 'seat-2', 'seat-3'];
      final seatDetails = {
        'seat-1': {'ticket_type_id': 'tt-vip', 'seat_code': 'A-01'},
        'seat-2': {'ticket_type_id': 'tt-vip', 'seat_code': 'A-02'},
        'seat-3': {'ticket_type_id': 'tt-reg', 'seat_code': 'B-01'},
      };

      // Grouping logic matching StaffDirectBookingPage
      final itemsByTicketType = <String, List<String>>{};
      for (final seatId in selectedSeatIds) {
        final seat = seatDetails[seatId];
        final ttId = seat?['ticket_type_id'] ?? '';
        itemsByTicketType.putIfAbsent(ttId, () => []).add(seatId);
      }

      final items = itemsByTicketType.entries.map((e) => {
        'ticket_type_id': e.key,
        'quantity': e.value.length,
        'session_seat_ids': e.value,
      }).toList();

      expect(items.length, 2);
      final vipItem = items.firstWhere((i) => i['ticket_type_id'] == 'tt-vip');
      expect(vipItem['quantity'], 2);
      expect(vipItem['session_seat_ids'], ['seat-1', 'seat-2']);

      final regItem = items.firstWhere((i) => i['ticket_type_id'] == 'tt-reg');
      expect(regItem['quantity'], 1);
      expect(regItem['session_seat_ids'], ['seat-3']);
    });

    test('Unseated event creates items with quantity and empty session_seat_ids list', () {
      final quantities = {
        'tt-ga': 3,
        'tt-early': 0,
        'tt-vip-standing': 2,
      };

      final items = quantities.entries
          .where((e) => e.value > 0)
          .map((e) => {
                'ticket_type_id': e.key,
                'quantity': e.value,
                'session_seat_ids': <String>[],
              })
          .toList();

      expect(items.length, 2);
      expect(items[0], {
        'ticket_type_id': 'tt-ga',
        'quantity': 3,
        'session_seat_ids': [],
      });
      expect(items[1], {
        'ticket_type_id': 'tt-vip-standing',
        'quantity': 2,
        'session_seat_ids': [],
      });
    });

    test('searchTickets returns empty list immediately when eventId is null or empty', () async {
      final res = await StaffService().searchTickets('John', eventId: '');
      expect(res, isEmpty);
    });
  });
}
