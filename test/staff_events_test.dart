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

  group('Staff assigned events normalization & extraction tests', () {
    test('extractListFromResponse handles direct List', () {
      final list = [{'id': 'e-1'}];
      expect(StaffService.extractListFromResponse(list), equals(list));
    });

    test('extractListFromResponse handles {success: true, data: [...]}', () {
      final response = {
        'success': true,
        'data': [{'id': 'e-1', 'title': 'Không gian trải nghiệm Porsche'}],
      };
      final list = StaffService.extractListFromResponse(response);
      expect(list.length, equals(1));
      expect(list.first['title'], equals('Không gian trải nghiệm Porsche'));
    });

    test('extractListFromResponse handles nested {data: {events: [...]}}', () {
      final response = {
        'success': true,
        'data': {
          'events': [{'id': 'e-porsche', 'title': 'Không gian trải nghiệm Porsche'}],
          'total': 1,
        },
      };
      final list = StaffService.extractListFromResponse(response);
      expect(list.length, equals(1));
      expect(list.first['title'], equals('Không gian trải nghiệm Porsche'));
    });

    test('extractListFromResponse handles nested {data: {assignments: [...]}}', () {
      final response = {
        'status': 'success',
        'data': {
          'assignments': [{'id': 'assign-1', 'event_id': 'e-porsche'}],
        },
      };
      final list = StaffService.extractListFromResponse(response);
      expect(list.length, equals(1));
      expect(list.first['event_id'], equals('e-porsche'));
    });

    test('normalizeStaffEvent extracts nested event and preserves assignment gate and role', () {
      final raw = {
        'id': 'assignment-999',
        'event_id': 'event-porsche-123',
        'role': 'Trưởng cửa soát vé',
        'gate': 'GATE 02 - VIP Lane',
        'zone': 'Khu Trải Nghiệm',
        'status': 'INVITED',
        'event': {
          'id': 'event-porsche-123',
          'title': 'Không gian trải nghiệm Porsche',
          'name': 'Không gian trải nghiệm Porsche',
          'venue': {
            'name': 'Porsche Studio Saigon',
            'city': 'TP. Hồ Chí Minh',
          },
          'start_time': '2026-11-10T09:00:00.000Z',
          'end_time': '2026-11-12T18:00:00.000Z',
          'banner_url': 'https://eventhub.vn/porsche.jpg',
        },
      };

      final normalized = StaffService.normalizeStaffEvent(raw);
      expect(normalized['id'], equals('event-porsche-123'));
      expect(normalized['assignment_id'], equals('assignment-999'));
      expect(normalized['title'], equals('Không gian trải nghiệm Porsche'));
      expect(normalized['venue_name'], equals('Porsche Studio Saigon'));
      expect(normalized['gate'], equals('GATE 02 - VIP Lane'));
      expect(normalized['zone'], equals('Khu Trải Nghiệm'));
      expect(normalized['role'], equals('Trưởng cửa soát vé'));
      expect(normalized['status'], equals('INVITED'));
      expect(normalized['banner_url'], equals('https://eventhub.vn/porsche.jpg'));
    });

    test('checkHasActiveOrUpcomingEvents handles normalized events and camelCase dates', () {
      final now = DateTime(2026, 11, 4, 12, 0, 0);
      final events = [
        {
          'id': 'event-porsche',
          'title': 'Không gian trải nghiệm Porsche',
          'startTime': '2026-11-10T09:00:00.000Z',
          'endTime': '2026-11-12T18:00:00.000Z',
        },
      ];

      expect(StaffService.checkHasActiveOrUpcomingEvents(events, referenceTime: now), isTrue);
    });
  });
}
