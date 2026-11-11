import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:eventhub_mobile/core/api/api_client.dart';
import 'package:eventhub_mobile/core/api/api_config.dart';
import 'package:eventhub_mobile/core/api/staff_service.dart';
import 'package:eventhub_mobile/core/models/ticket_model.dart';

String _encodeJwt(Map<String, dynamic> payload) {
  final headerB64 = base64Url.encode(utf8.encode(jsonEncode({'alg': 'HS256', 'typ': 'JWT'}))).replaceAll('=', '');
  final payloadB64 = base64Url.encode(utf8.encode(jsonEncode(payload))).replaceAll('=', '');
  return '$headerB64.$payloadB64.fake-signature';
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() {
    ApiClient().resetForTesting();
  });

  group('ApiClient token helpers', () {
    test('extractRefreshTokenFromSetCookie parses single and combined Set-Cookie headers', () {
      expect(
        ApiClient.extractRefreshTokenFromSetCookie(
          'refresh_token=rt-abc-123; Path=/; HttpOnly; SameSite=Lax',
        ),
        equals('rt-abc-123'),
      );

      expect(
        ApiClient.extractRefreshTokenFromSetCookie(
          'theme=dark; Path=/, refresh_token=rt%2Bencoded%3D1; Path=/api/auth; HttpOnly',
        ),
        equals('rt+encoded=1'),
      );

      expect(ApiClient.extractRefreshTokenFromSetCookie('session=only-other; Path=/'), isNull);
      expect(ApiClient.extractRefreshTokenFromSetCookie(null), isNull);
    });

    test('isJwtExpired handles past, skew, future, and non-JWT strings', () {
      final now = DateTime.utc(2026, 11, 11, 12, 0, 0);
      final expiredJwt = _encodeJwt({
        'sub': 'user-1',
        'exp': now.subtract(const Duration(minutes: 5)).millisecondsSinceEpoch ~/ 1000,
      });
      final nearlyExpiredJwt = _encodeJwt({
        'sub': 'user-1',
        'exp': now.add(const Duration(seconds: 20)).millisecondsSinceEpoch ~/ 1000,
      });
      final freshJwt = _encodeJwt({
        'sub': 'user-1',
        'exp': now.add(const Duration(minutes: 15)).millisecondsSinceEpoch ~/ 1000,
      });

      expect(ApiClient.isJwtExpired(expiredJwt, now: now), isTrue);
      expect(ApiClient.isJwtExpired(nearlyExpiredJwt, now: now), isFalse);
      expect(ApiClient.isJwtExpired(nearlyExpiredJwt, skew: const Duration(seconds: 30), now: now), isTrue);
      expect(ApiClient.isJwtExpired(freshJwt, skew: const Duration(seconds: 30), now: now), isFalse);
      expect(ApiClient.isJwtExpired('opaque-test-token', now: now), isFalse);
      expect(ApiClient.isJwtExpired(null, now: now), isFalse);
    });
  });

  group('ApiClient cookie capture & single-flight 401 refresh', () {
    test('captures refresh_token cookie on /auth/login and updates tokens on refresh', () async {
      final client = ApiClient();
      final updatedTokens = <List<String?>>[];
      client.setSessionCallbacks(
        onTokensUpdated: (access, refresh) => updatedTokens.add([access, refresh]),
      );

      client.setHttpClientForTesting(
        MockClient((request) async {
          if (request.url.path.endsWith('/auth/login')) {
            return http.Response(
              jsonEncode({
                'success': true,
                'data': {
                  'accessToken': 'access-initial',
                  'user': {'id': 'staff-1', 'roles': ['STAFF']},
                },
              }),
              200,
              headers: {
                'content-type': 'application/json',
                'set-cookie': 'refresh_token=rt-initial; Path=/; HttpOnly',
              },
            );
          }

          if (request.url.path.endsWith('/auth/refresh')) {
            expect(request.headers['cookie'], contains('refresh_token=rt-initial'));
            return http.Response(
              jsonEncode({
                'success': true,
                'data': {'accessToken': 'access-rotated'},
              }),
              200,
              headers: {
                'content-type': 'application/json',
                'set-cookie': 'refresh_token=rt-rotated; Path=/; HttpOnly',
              },
            );
          }

          return http.Response('Not found', 404);
        }),
      );

      final loginRes = await client.post(ApiConfig.login, {'email': 'a@b.vn', 'password': 'secret'});
      expect(loginRes?['success'], isTrue);
      expect(client.refreshToken, equals('rt-initial'));

      // Simulate AuthService storing accessToken after login then refreshing
      client.setAuthTokens(accessToken: 'access-initial');
      final refreshed = await client.refreshAccessToken();
      expect(refreshed, isTrue);
      expect(client.authToken, equals('access-rotated'));
      expect(client.refreshToken, equals('rt-rotated'));
      expect(updatedTokens.last, equals(['access-rotated', 'rt-rotated']));
    });

    test('concurrent 401 staff requests trigger a single /auth/refresh and retry to 200', () async {
      final client = ApiClient();
      final futureJwt = _encodeJwt({
        'sub': 'staff-1',
        'roles': ['STAFF'],
        'exp': DateTime.now().toUtc().add(const Duration(minutes: 15)).millisecondsSinceEpoch ~/ 1000,
      });
      final refreshedJwt = _encodeJwt({
        'sub': 'staff-1',
        'roles': ['STAFF'],
        'exp': DateTime.now().toUtc().add(const Duration(minutes: 30)).millisecondsSinceEpoch ~/ 1000,
      });

      client.setAuthTokens(accessToken: futureJwt, refreshToken: 'rt-valid');

      var refreshCount = 0;
      var verifyAttempts = 0;
      var searchAttempts = 0;

      client.setHttpClientForTesting(
        MockClient((request) async {
          final path = request.url.path;
          if (path.endsWith('/auth/refresh')) {
            refreshCount++;
            expect(request.headers['cookie'], contains('refresh_token=rt-valid'));
            await Future<void>.delayed(const Duration(milliseconds: 20));
            return http.Response(
              jsonEncode({
                'success': true,
                'data': {'accessToken': refreshedJwt},
              }),
              200,
              headers: {
                'content-type': 'application/json',
                'set-cookie': 'refresh_token=rt-next; Path=/; HttpOnly',
              },
            );
          }

          final authHeader = request.headers['authorization'] ?? '';
          if (path.endsWith('/staff/tickets/verify-qr')) {
            verifyAttempts++;
            if (authHeader == 'Bearer $futureJwt') {
              return http.Response(
                jsonEncode({
                  'success': false,
                  'errorCode': 'AUTH_INVALID_TOKEN',
                  'message': 'Đã xảy ra lỗi. Vui lòng thử lại.',
                }),
                401,
                headers: {'content-type': 'application/json'},
              );
            }
            if (authHeader == 'Bearer $refreshedJwt') {
              return http.Response(
                jsonEncode({
                  'success': true,
                  'data': {
                    'ticket': {
                      'id': 't-1',
                      'ticket_code': 'EH-001',
                      'status': 'VALID',
                      'attendee_name': 'Nguyen Van A',
                    },
                  },
                }),
                200,
                headers: {'content-type': 'application/json'},
              );
            }
          }

          if (path.endsWith('/staff/tickets/search')) {
            searchAttempts++;
            if (authHeader == 'Bearer $futureJwt') {
              return http.Response(
                jsonEncode({
                  'success': false,
                  'errorCode': 'AUTH_INVALID_TOKEN',
                  'message': 'Đã xảy ra lỗi. Vui lòng thử lại.',
                }),
                401,
                headers: {'content-type': 'application/json'},
              );
            }
            if (authHeader == 'Bearer $refreshedJwt') {
              return http.Response(
                jsonEncode({
                  'success': true,
                  'data': {
                    'tickets': [
                      {
                        'id': 't-1',
                        'ticket_code': 'EH-001',
                        'status': 'VALID',
                        'attendee_name': 'Nguyen Van A',
                      },
                    ],
                  },
                }),
                200,
                headers: {'content-type': 'application/json'},
              );
            }
          }

          return http.Response('Unexpected path: $path', 500);
        }),
      );

      final results = await Future.wait([
        StaffService().verifyQr('EH-001'),
        StaffService().searchTicketsResult(eventId: 'evt-1', query: 'EH-001'),
      ]);

      expect(refreshCount, equals(1));
      expect(verifyAttempts, equals(2));
      expect(searchAttempts, equals(2));
      expect(client.authToken, equals(refreshedJwt));
      expect(client.refreshToken, equals('rt-next'));

      expect(results[0]['success'], isTrue);
      expect(results[0]['ticket'], isA<TicketModel>());
      expect((results[0]['ticket'] as TicketModel).ticketCode, equals('EH-001'));

      expect(results[1]['success'], isTrue);
      final tickets = results[1]['tickets'] as List<TicketModel>;
      expect(tickets, hasLength(1));
      expect(tickets.first.ticketCode, equals('EH-001'));
    });

    test('unrecoverable 401 returns requiresLogin: true across StaffService without public event fallback', () async {
      final client = ApiClient();
      final validFormatJwt = _encodeJwt({
        'sub': 'staff-1',
        'exp': DateTime.now().toUtc().add(const Duration(minutes: 10)).millisecondsSinceEpoch ~/ 1000,
      });
      client.setAuthTokens(accessToken: validFormatJwt, refreshToken: 'rt-expired');

      var authExpiredFired = 0;
      var publicEventsCalled = 0;
      client.setSessionCallbacks(
        onAuthExpired: () async {
          authExpiredFired++;
        },
      );

      client.setHttpClientForTesting(
        MockClient((request) async {
          final path = request.url.path;
          if (path == '/api/events') {
            publicEventsCalled++;
          }
          return http.Response(
            jsonEncode({
              'success': false,
              'errorCode': 'AUTH_INVALID_TOKEN',
              'message': 'Đã xảy ra lỗi. Vui lòng thử lại.',
            }),
            401,
            headers: {'content-type': 'application/json'},
          );
        }),
      );

      final eventsRes = await StaffService().getAssignedEventsResult();
      expect(eventsRes['success'], isFalse);
      expect(eventsRes['requiresLogin'], isTrue);
      expect(eventsRes['events'], isEmpty);
      expect(publicEventsCalled, equals(0));
      expect(authExpiredFired, greaterThanOrEqualTo(1));

      // Re-seed stale access token to verify direct verifyQr & searchTicketsResult also surface requiresLogin
      client.setAuthTokens(accessToken: validFormatJwt, refreshToken: null);
      final verifyRes = await StaffService().verifyQr('EH-001');
      final searchRes = await StaffService().searchTicketsResult(eventId: 'evt-1', query: 'EH-001');

      expect(verifyRes['success'], isFalse);
      expect(verifyRes['requiresLogin'], isTrue);
      expect(searchRes['success'], isFalse);
      expect(searchRes['requiresLogin'], isTrue);
    });
  });
}

