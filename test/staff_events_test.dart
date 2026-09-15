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
  });
}
