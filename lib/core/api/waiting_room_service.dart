import 'package:shared_preferences/shared_preferences.dart';
import '../models/waiting_room_model.dart';
import 'api_client.dart';
import 'api_config.dart';

class WaitingRoomService {
  static final WaitingRoomService _instance = WaitingRoomService._internal();
  factory WaitingRoomService() => _instance;
  WaitingRoomService._internal();

  String _sessionKey(String eventId) => 'eventhub_queue_session_$eventId';
  String _tokenKey(String eventId) => 'eventhub_booking_token_$eventId';
  String _tokenExpiryKey(String eventId) => 'eventhub_booking_expiry_$eventId';

  /// Join the Virtual Waiting Room or restore an existing session
  Future<WaitingRoomModel> joinQueue(String eventId, {String? sessionId}) async {
    final effectiveSessionId = sessionId ?? await getSavedSessionId(eventId);

    final payload = <String, dynamic>{
      if (effectiveSessionId != null && effectiveSessionId.isNotEmpty)
        'session_id': effectiveSessionId,
    };

    final response = await ApiClient().post(
      ApiConfig.queueJoin(eventId),
      payload,
    );

    final model = WaitingRoomModel.fromJson(response);

    if (model.sessionId != null && model.sessionId!.isNotEmpty) {
      await saveSessionId(eventId, model.sessionId!);
    }

    if (model.isAdmitted && model.bookingToken != null && model.bookingToken!.isNotEmpty) {
      ApiClient().setBookingToken(model.bookingToken);
      await saveBookingToken(
        eventId,
        model.bookingToken!,
        remainingSeconds: model.remainingSeconds,
      );
    }

    return model;
  }

  /// Poll queue position and status
  Future<WaitingRoomModel> getQueueStatus(String eventId, String sessionId) async {
    final response = await ApiClient().get(
      ApiConfig.queueStatus(eventId),
      queryParams: {'sessionId': sessionId},
    );

    final model = WaitingRoomModel.fromJson(response);

    if (model.isAdmitted && model.bookingToken != null && model.bookingToken!.isNotEmpty) {
      ApiClient().setBookingToken(model.bookingToken);
      await saveBookingToken(
        eventId,
        model.bookingToken!,
        remainingSeconds: model.remainingSeconds,
      );
    }

    return model;
  }

  /// Leave queue voluntarily
  Future<bool> leaveQueue(String eventId, String sessionId) async {
    try {
      await ApiClient().post(
        ApiConfig.queueLeave(eventId),
        {'session_id': sessionId},
      );
    } catch (_) {}

    await clearSavedSession(eventId);
    await clearBookingToken(eventId);
    return true;
  }

  // --- Session & Token Persistence Helpers ---

  Future<String?> getSavedSessionId(String eventId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_sessionKey(eventId));
    } catch (_) {
      return null;
    }
  }

  Future<void> saveSessionId(String eventId, String sessionId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_sessionKey(eventId), sessionId);
    } catch (_) {}
  }

  Future<void> clearSavedSession(String eventId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_sessionKey(eventId));
    } catch (_) {}
  }

  Future<String?> getSavedBookingToken(String eventId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString(_tokenKey(eventId));
      final expiryMs = prefs.getInt(_tokenExpiryKey(eventId));

      if (token == null || token.isEmpty) return null;

      if (expiryMs != null) {
        final nowMs = DateTime.now().millisecondsSinceEpoch;
        if (nowMs >= expiryMs) {
          // Token expired -> clean up
          await clearBookingToken(eventId);
          return null;
        }
      }

      // Sync active booking token into ApiClient
      ApiClient().setBookingToken(token);
      return token;
    } catch (_) {
      return null;
    }
  }

  Future<void> saveBookingToken(
    String eventId,
    String token, {
    int remainingSeconds = 600,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final expiryMs = DateTime.now().millisecondsSinceEpoch + (remainingSeconds * 1000);
      await prefs.setString(_tokenKey(eventId), token);
      await prefs.setInt(_tokenExpiryKey(eventId), expiryMs);
      ApiClient().setBookingToken(token);
    } catch (_) {}
  }

  Future<void> clearBookingToken(String eventId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_tokenKey(eventId));
      await prefs.remove(_tokenExpiryKey(eventId));
      if (ApiClient().bookingToken != null) {
        ApiClient().clearBookingToken();
      }
    } catch (_) {}
  }
}

