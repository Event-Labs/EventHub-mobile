import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:eventhub_mobile/core/api/api_client.dart';
import 'package:eventhub_mobile/core/api/waiting_room_service.dart';
import 'package:eventhub_mobile/core/models/event_model.dart';
import 'package:eventhub_mobile/core/models/waiting_room_model.dart';
import 'package:eventhub_mobile/features/home/presentation/pages/waiting_room_page.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    ApiClient().resetForTesting();
  });

  tearDown(() {
    ApiClient().resetForTesting();
  });

  group('WaitingRoomModel & Parsing Tests', () {
    test('parses WAITING / QUEUED response accurately', () {
      final json = {
        'status': 'WAITING',
        'enabled': true,
        'session_id': 'sess-1234',
        'position': 12,
        'total_waiting': 45,
        'is_near_turn': false,
        'estimated_wait_seconds': 36,
        'poll_interval_ms': 3000,
        'event': {
          'title': 'Grand Symphony 2026',
          'banner_url': 'https://example.com/banner.jpg',
          'thumbnail_url': 'https://example.com/thumb.jpg',
        },
      };

      final model = WaitingRoomModel.fromJson(json);

      expect(model.enabled, isTrue);
      expect(model.rawStatus, equals('WAITING'));
      expect(model.isWaiting, isTrue);
      expect(model.isAdmitted, isFalse);
      expect(model.sessionId, equals('sess-1234'));
      expect(model.position, equals(12));
      expect(model.totalWaiting, equals(45));
      expect(model.isNearTurn, isFalse);
      expect(model.status, equals(WaitingRoomStatus.waiting));
      expect(model.eventTitle, equals('Grand Symphony 2026'));
      expect(model.eventBannerUrl, equals('https://example.com/banner.jpg'));
    });

    test('identifies NEAR_TURN when position is 5 or below or flag is true', () {
      final jsonNearPos = {
        'status': 'WAITING',
        'enabled': true,
        'session_id': 'sess-near-1',
        'position': 3,
        'total_waiting': 10,
        'is_near_turn': false,
      };

      final modelNearPos = WaitingRoomModel.fromJson(jsonNearPos);
      expect(modelNearPos.isNearTurn, isTrue);
      expect(modelNearPos.status, equals(WaitingRoomStatus.nearTurn));

      final jsonNearFlag = {
        'status': 'QUEUED',
        'enabled': true,
        'session_id': 'sess-near-2',
        'position': 8,
        'total_waiting': 20,
        'is_near_turn': true,
      };

      final modelNearFlag = WaitingRoomModel.fromJson(jsonNearFlag);
      expect(modelNearFlag.isNearTurn, isTrue);
      expect(modelNearFlag.status, equals(WaitingRoomStatus.nearTurn));
    });

    test('parses ADMITTED / ACTIVE response with booking token & expiry', () {
      final json = {
        'status': 'ACTIVE',
        'enabled': true,
        'session_id': 'sess-active-99',
        'booking_token': 'bkt-secure-token-abc',
        'remaining_seconds': 540,
        'expires_at': '2026-11-13T18:00:00.000Z',
      };

      final model = WaitingRoomModel.fromJson(json);

      expect(model.isAdmitted, isTrue);
      expect(model.bookingToken, equals('bkt-secure-token-abc'));
      expect(model.remainingSeconds, equals(540));
      expect(model.status, equals(WaitingRoomStatus.admitted));
      expect(model.expiresAt, isNotNull);
    });

    test('parses SOLD_OUT, EXPIRED, PAUSED, and DIRECT_ACCESS states', () {
      final soldOut = WaitingRoomModel.fromJson({'status': 'SOLD_OUT', 'enabled': true});
      expect(soldOut.isSoldOut, isTrue);
      expect(soldOut.status, equals(WaitingRoomStatus.soldOut));

      final expired = WaitingRoomModel.fromJson({'status': 'EXPIRED', 'enabled': true});
      expect(expired.isExpired, isTrue);
      expect(expired.status, equals(WaitingRoomStatus.expired));

      final paused = WaitingRoomModel.fromJson({'status': 'PAUSED', 'enabled': true});
      expect(paused.isPaused, isTrue);
      expect(paused.status, equals(WaitingRoomStatus.paused));

      final direct = WaitingRoomModel.fromJson({'status': 'DIRECT_ACCESS', 'enabled': false});
      expect(direct.isDirectAccess, isTrue);
      expect(direct.status, equals(WaitingRoomStatus.directAccess));
    });

    test('formatCountdown outputs mm:ss correctly', () {
      expect(WaitingRoomModel.formatCountdown(600), equals('10:00'));
      expect(WaitingRoomModel.formatCountdown(65), equals('01:05'));
      expect(WaitingRoomModel.formatCountdown(9), equals('00:09'));
      expect(WaitingRoomModel.formatCountdown(0), equals('00:00'));
      expect(WaitingRoomModel.formatCountdown(-5), equals('00:00'));
    });
  });

  group('EventModel Waiting Room Config Integration Tests', () {
    test('isWaitingRoomEnabled returns true when enabled in JSON', () {
      final event1 = EventModel.fromJson({
        'id': 'evt-wr-1',
        'title': 'Mega Concert',
        'waiting_room_config': {'enabled': true, 'max_active': 100},
      });
      expect(event1.isWaitingRoomEnabled, isTrue);

      final event2 = EventModel.fromJson({
        'id': 'evt-wr-2',
        'title': 'Mega Concert 2',
        'waiting_room_config': {'enabled': 'true'},
      });
      expect(event2.isWaitingRoomEnabled, isTrue);

      final event3 = EventModel.fromJson({
        'id': 'evt-wr-3',
        'title': 'Mega Concert 3',
        'waiting_room_config': {'enabled': 1},
      });
      expect(event3.isWaitingRoomEnabled, isTrue);
    });

    test('isWaitingRoomEnabled returns false when null, missing, or false', () {
      final eventNull = EventModel.fromJson({'id': 'evt-1', 'title': 'Event Normal'});
      expect(eventNull.isWaitingRoomEnabled, isFalse);

      final eventDisabled = EventModel.fromJson({
        'id': 'evt-2',
        'title': 'Event Normal 2',
        'waiting_room_config': {'enabled': false},
      });
      expect(eventDisabled.isWaitingRoomEnabled, isFalse);
    });
  });

  group('ApiClient Booking Token Header Tests', () {
    test('attaches x-booking-token to outgoing request headers when set', () async {
      String? sentBookingToken;

      final mockClient = MockClient((request) async {
        sentBookingToken = request.headers['x-booking-token'];
        return http.Response(
          jsonEncode({'success': true, 'data': {'status': 'OK'}}),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      ApiClient().setHttpClientForTesting(mockClient);
      ApiClient().setBookingToken('token-queue-xyz-789');

      final res = await ApiClient().get('/events/test');
      expect(res['success'], isTrue);
      expect(sentBookingToken, equals('token-queue-xyz-789'));

      // Clear token and check that header is no longer sent
      ApiClient().clearBookingToken();
      await ApiClient().get('/events/test');
      expect(sentBookingToken, isNull);
    });
  });

  group('WaitingRoomService Persistence & API Tests', () {
    test('joinQueue saves session_id and booking_token when admitted', () async {
      final mockClient = MockClient((request) async {
        if (request.url.path.contains('/queue/join')) {
          return http.Response(
            jsonEncode({
              'success': true,
              'data': {
                'enabled': true,
                'status': 'ACTIVE',
                'session_id': 'sess-saved-101',
                'booking_token': 'bkt-saved-token-202',
                'remaining_seconds': 600,
              },
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response('{"success":false}', 404);
      });

      ApiClient().setHttpClientForTesting(mockClient);

      final service = WaitingRoomService();
      final result = await service.joinQueue('event-omega-1');

      expect(result.isAdmitted, isTrue);
      expect(result.sessionId, equals('sess-saved-101'));
      expect(result.bookingToken, equals('bkt-saved-token-202'));

      // Verify token persisted in SharedPreferences and loaded
      final savedToken = await service.getSavedBookingToken('event-omega-1');
      expect(savedToken, equals('bkt-saved-token-202'));
      expect(ApiClient().bookingToken, equals('bkt-saved-token-202'));
    });

    test('leaveQueue clears saved session and booking token', () async {
      final mockClient = MockClient((request) async {
        return http.Response(
          jsonEncode({'success': true, 'data': {'left': true}}),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      ApiClient().setHttpClientForTesting(mockClient);

      final service = WaitingRoomService();
      await service.saveSessionId('event-leave-1', 'sess-leave-999');
      await service.saveBookingToken('event-leave-1', 'bkt-leave-999');

      expect(await service.getSavedSessionId('event-leave-1'), equals('sess-leave-999'));

      final success = await service.leaveQueue('event-leave-1', 'sess-leave-999');
      expect(success, isTrue);

      expect(await service.getSavedSessionId('event-leave-1'), isNull);
      expect(await service.getSavedBookingToken('event-leave-1'), isNull);
    });
  });

  group('WaitingRoomPage Widget UI Tests', () {
    final testEvent = EventModel.fromJson({
      'id': 'evt-ui-test-1',
      'title': 'Born Pink World Tour',
      'waiting_room_config': {'enabled': true},
    });

    testWidgets('renders Waiting Room header and queue elements', (tester) async {
      final mockClient = MockClient((request) async {
        if (request.url.path.contains('/queue/join')) {
          return http.Response(
            jsonEncode({
              'success': true,
              'data': {
                'enabled': true,
                'status': 'WAITING',
                'session_id': 'sess-widget-1',
                'position': 25,
                'total_waiting': 100,
                'is_near_turn': false,
                'estimated_wait_seconds': 75,
                'poll_interval_ms': 5000,
              },
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response('{"success":false}', 404);
      });

      ApiClient().setHttpClientForTesting(mockClient);

      await tester.pumpWidget(
        MaterialApp(
          home: WaitingRoomPage(event: testEvent),
        ),
      );

      // Initial loading render
      expect(find.text('PHÒNG CHỜ ẢO'), findsOneWidget);
      expect(find.text('Quay lại'), findsOneWidget);

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('BORN PINK WORLD TOUR'), findsOneWidget);
      expect(find.text('SỐ NGƯỜI ĐANG XẾP HÀNG TRƯỚC BẠN'), findsOneWidget);
      expect(find.text('25'), findsOneWidget);
      expect(find.text('Đừng thoát ứng dụng, bạn sẽ mất lượt mua vé.'), findsOneWidget);
      expect(find.text('Thời gian chờ dự kiến: ~2 phút'), findsOneWidget);
    });

    testWidgets('renders Admitted state with turn announcement and proceed button', (tester) async {
      final mockClient = MockClient((request) async {
        if (request.url.path.contains('/queue/join')) {
          return http.Response(
            jsonEncode({
              'success': true,
              'data': {
                'enabled': true,
                'status': 'ACTIVE',
                'session_id': 'sess-widget-admit',
                'booking_token': 'bkt-ready-123',
                'remaining_seconds': 600,
              },
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response('{"success":false}', 404);
      });

      ApiClient().setHttpClientForTesting(mockClient);

      await tester.pumpWidget(
        MaterialApp(
          home: WaitingRoomPage(event: testEvent),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('ĐÃ ĐẾN LƯỢT CỦA BẠN!'), findsOneWidget);
      expect(find.text('Bạn đã được cấp quyền vào khu vực đặt vé.'), findsOneWidget);
      expect(find.text('Thời gian còn lại để đặt vé'), findsOneWidget);
      expect(find.text('TIẾN HÀNH CHỌN VÉ NGAY'), findsOneWidget);
    });
  });
}
