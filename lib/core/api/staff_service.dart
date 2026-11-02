import 'dart:convert';
import '../models/ticket_model.dart';
import 'api_client.dart';
import 'api_config.dart';

class StaffService {
  static final StaffService _instance = StaffService._internal();
  factory StaffService() => _instance;
  StaffService._internal();

  /// Parse QR code string: if JSON was encoded in the QR, extract ticket_code and ticket_id
  static Map<String, String> parseQrPayload(String rawCode) {
    final clean = rawCode.trim();
    if ((clean.startsWith('{') && clean.endsWith('}')) || (clean.startsWith('{"') && clean.contains('}'))) {
      try {
        final decoded = jsonDecode(clean);
        if (decoded is Map) {
          final ticketCode = decoded['ticket_code']?.toString() ?? decoded['code']?.toString() ?? '';
          final ticketId = decoded['ticket_id']?.toString() ?? decoded['id']?.toString() ?? '';
          final qrCodeVal = decoded['qr_code']?.toString() ?? '';
          final effective = ticketCode.isNotEmpty
              ? ticketCode
              : (qrCodeVal.isNotEmpty ? qrCodeVal : (ticketId.isNotEmpty ? ticketId : clean));
          return {
            'effective_code': effective,
            'ticket_code': ticketCode,
            'ticket_id': ticketId,
            'qr_code': qrCodeVal.isNotEmpty ? qrCodeVal : effective,
          };
        }
      } catch (_) {}
    }
    return {
      'effective_code': clean,
      'ticket_code': clean,
      'ticket_id': '',
      'qr_code': clean,
    };
  }

  /// Sanitize error messages so that no raw JSON or technical stack traces are shown
  static String sanitizeStaffMessage(dynamic rawMsg, {String? defaultMsg}) {
    if (rawMsg == null) return defaultMsg ?? 'Không tìm thấy thông tin vé!';
    final str = rawMsg.toString().trim();
    if (str.isEmpty) return defaultMsg ?? 'Không tìm thấy thông tin vé!';

    // If message is or contains JSON, parse message property or sanitize
    if ((str.startsWith('{') && str.endsWith('}')) || str.contains('"errorCode"') || str.contains('SyntaxError')) {
      try {
        final decoded = jsonDecode(str);
        if (decoded is Map && decoded['message'] != null) {
          return sanitizeStaffMessage(decoded['message'], defaultMsg: defaultMsg);
        }
      } catch (_) {}
      return 'Mã QR không hợp lệ hoặc không thuộc hệ thống EventHub.';
    }

    final lower = str.toLowerCase();
    if (lower.contains('not found') || lower.contains('không tìm thấy') || lower.contains('ticket_not_found')) {
      return 'Không tìm thấy vé trong hệ thống hoặc mã vé không tồn tại.';
    }
    if (lower.contains('already checked') || lower.contains('đã check-in') || lower.contains('already_used')) {
      return 'Vé này đã được check-in trước đó.';
    }
    if (lower.contains('auth_required') || lower.contains('not authorized') || lower.contains('không có quyền')) {
      return 'Tài khoản không có quyền thực hiện soát vé cho sự kiện này.';
    }
    if (lower.contains('invalid') || lower.contains('không hợp lệ')) {
      return 'Mã vé không hợp lệ hoặc đã hết hạn.';
    }
    if (lower.contains('cancelled') || lower.contains('đã hủy') || lower.contains('refunded')) {
      return 'Vé này đã bị hủy hoặc hoàn tiền.';
    }

    // Strip any residual json braces
    final clean = str.replaceAll(RegExp(r'\{.*?\}'), '').trim();
    return clean.isNotEmpty ? clean : (defaultMsg ?? 'Thao tác soát vé không thành công.');
  }

  /// Check-in ticket using QR code payload (extracts clean code, never outputs raw JSON)
  Future<Map<String, dynamic>> checkInByQr(String qrCode, {String? gate}) async {
    try {
      final parsed = parseQrPayload(qrCode);
      final effectiveCode = parsed['effective_code']!;
      final payload = <String, dynamic>{
        'code': effectiveCode,
        'qr_code': parsed['qr_code'] ?? effectiveCode,
        'gate': gate ?? 'GATE 01',
        if (parsed['ticket_id'] != null && parsed['ticket_id']!.isNotEmpty)
          'ticket_id': parsed['ticket_id'],
      };

      final response = await ApiClient().post(ApiConfig.staffCheckInQr, payload);

      if (response != null && response['success'] == true) {
        final ticketData = response['data']?['ticket'] ?? response['data'];
        TicketModel? ticket;
        if (ticketData != null && ticketData is Map<String, dynamic>) {
          ticket = TicketModel.fromJson(ticketData);
        }
        return {
          'success': true,
          'message': response['message'] ?? 'Check-in thành công!',
          'ticket': ticket,
          'ticket_code': ticket?.ticketCode ?? (parsed['ticket_code']?.isNotEmpty == true ? parsed['ticket_code'] : effectiveCode),
          'raw': response['data'],
        };
      }

      final errorMsg = sanitizeStaffMessage(
        response?['message'] ?? response?['error']?['message'],
        defaultMsg: 'Mã vé không hợp lệ hoặc vé không thể soát.',
      );
      return {
        'success': false,
        'message': errorMsg,
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Lỗi kết nối khi quét vé: $e',
      };
    }
  }

  /// Verify QR without completing check-in (preview ticket info, extracts clean code)
  Future<Map<String, dynamic>> verifyQr(String qrCode) async {
    try {
      final parsed = parseQrPayload(qrCode);
      final effectiveCode = parsed['effective_code']!;
      final payload = <String, dynamic>{
        'code': effectiveCode,
        'qr_code': parsed['qr_code'] ?? effectiveCode,
        if (parsed['ticket_id'] != null && parsed['ticket_id']!.isNotEmpty)
          'ticket_id': parsed['ticket_id'],
      };

      final response = await ApiClient().post(ApiConfig.staffVerifyQr, payload);

      if (response != null && response['success'] == true && response['data'] != null) {
        final ticketData = response['data']?['ticket'] ?? response['data'];
        TicketModel? ticket;
        if (ticketData != null && ticketData is Map<String, dynamic>) {
          ticket = TicketModel.fromJson(ticketData);
        }
        return {
          'success': true,
          'message': response['message'] ?? 'Vé hợp lệ!',
          'ticket': ticket,
          'ticket_code': ticket?.ticketCode ?? (parsed['ticket_code']?.isNotEmpty == true ? parsed['ticket_code'] : effectiveCode),
          'raw': response['data'],
        };
      }

      final errorMsg = sanitizeStaffMessage(
        response?['message'] ?? response?['error']?['message'],
        defaultMsg: 'Không tìm thấy thông tin vé hoặc mã QR không tồn tại.',
      );
      return {
        'success': false,
        'message': errorMsg,
        'ticket_code': parsed['ticket_code']?.isNotEmpty == true ? parsed['ticket_code'] : null,
      };
    } catch (e) {
      return {'success': false, 'message': 'Lỗi xác thực vé: $e'};
    }
  }

  /// Search tickets by attendee name, email, or ticket code for a specific event
  Future<List<TicketModel>> searchTickets(
    String query, {
    String? eventId,
    String? ticketCode,
    String? buyerName,
    String? buyerEmail,
    String? buyerPhone,
  }) async {
    return searchTicketsWithFilters(
      query: query,
      eventId: eventId,
      ticketCode: ticketCode,
      buyerName: buyerName,
      buyerEmail: buyerEmail,
      buyerPhone: buyerPhone,
    );
  }

  /// Detailed search tickets with filters
  Future<List<TicketModel>> searchTicketsWithFilters({
    String? query,
    String? eventId,
    String? ticketCode,
    String? buyerName,
    String? buyerEmail,
    String? buyerPhone,
  }) async {
    final effectiveEventId = eventId ?? '';
    if (effectiveEventId.isEmpty) {
      return [];
    }

    final payload = <String, dynamic>{
      'eventId': effectiveEventId,
    };

    if (ticketCode != null && ticketCode.trim().isNotEmpty) {
      payload['ticketCode'] = ticketCode.trim();
    }
    if (buyerName != null && buyerName.trim().isNotEmpty) {
      payload['buyerName'] = buyerName.trim();
    }
    if (buyerEmail != null && buyerEmail.trim().isNotEmpty) {
      payload['buyerEmail'] = buyerEmail.trim();
    }
    if (buyerPhone != null && buyerPhone.trim().isNotEmpty) {
      payload['buyerPhone'] = buyerPhone.trim();
    }

    final rawQ = query?.trim() ?? '';
    if (rawQ.isNotEmpty && ticketCode == null && buyerName == null && buyerEmail == null && buyerPhone == null) {
      if (rawQ.contains('@')) {
        payload['buyerEmail'] = rawQ;
      } else if (RegExp(r'^\+?[0-9]{8,15}$').hasMatch(rawQ)) {
        payload['buyerPhone'] = rawQ;
      } else if (rawQ.contains('-') || rawQ.toUpperCase().startsWith('TK') || rawQ.toUpperCase().startsWith('TICK')) {
        payload['ticketCode'] = rawQ;
      } else {
        payload['buyerName'] = rawQ;
      }
    }

    try {
      final response = await ApiClient().post(ApiConfig.staffSearchTickets, payload);

      if (response != null && response['success'] == true && response['data'] != null) {
        final data = response['data'];
        final List list = (data is Map && data['tickets'] is List)
            ? (data['tickets'] as List)
            : (data is List ? data : []);
        final tickets = list
            .whereType<Map<String, dynamic>>()
            .map((e) => TicketModel.fromJson(e))
            .toList();

        // If generic text search returned 0 items with buyerName, try ticketCode as fallback
        if (tickets.isEmpty &&
            rawQ.isNotEmpty &&
            payload.containsKey('buyerName') &&
            !rawQ.contains('@') &&
            !RegExp(r'^\+?[0-9]{8,15}$').hasMatch(rawQ)) {
          final fallbackPayload = <String, dynamic>{
            'eventId': effectiveEventId,
            'ticketCode': rawQ,
          };
          final fbResponse = await ApiClient().post(ApiConfig.staffSearchTickets, fallbackPayload);
          if (fbResponse != null && fbResponse['success'] == true && fbResponse['data'] != null) {
            final fbData = fbResponse['data'];
            final List fbList = (fbData is Map && fbData['tickets'] is List)
                ? (fbData['tickets'] as List)
                : (fbData is List ? fbData : []);
            return fbList
                .whereType<Map<String, dynamic>>()
                .map((e) => TicketModel.fromJson(e))
                .toList();
          }
        }

        return tickets;
      }
    } catch (_) {}

    return [];
  }

  /// Manual check-in by ticket ID
  Future<Map<String, dynamic>> manualCheckIn(String ticketId, {String? gate}) async {
    try {
      final patchResponse = await ApiClient().patch('/staff/tickets/$ticketId/check-in', {
        'gate': gate ?? 'GATE 01',
      });
      if (patchResponse != null && patchResponse['success'] == true) {
        final ticketData = patchResponse['data']?['ticket'] ?? patchResponse['data'];
        TicketModel? ticket;
        if (ticketData != null && ticketData is Map<String, dynamic>) {
          ticket = TicketModel.fromJson(ticketData);
        }
        return {
          'success': true,
          'message': patchResponse['message'] ?? 'Check-in thành công!',
          'ticket': ticket,
        };
      }

      final errorMsg = sanitizeStaffMessage(
        patchResponse?['message'] ?? patchResponse?['error']?['message'],
        defaultMsg: 'Không thể check-in vé này!',
      );
      return {
        'success': false,
        'message': errorMsg,
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Lỗi kết nối khi check-in: $e',
      };
    }
  }

  /// Get staff overview statistics (total scanned, active gates, etc.)
  Future<Map<String, dynamic>?> getStaffOverview() async {
    try {
      final response = await ApiClient().get(ApiConfig.staffOverview);
      if (response != null && response['success'] == true && response['data'] is Map) {
        return Map<String, dynamic>.from(response['data'] as Map);
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  /// Get check-in report for a specific event or all assigned events
  Future<Map<String, dynamic>?> getStaffCheckInReport([String? eventId]) async {
    try {
      final response = await ApiClient().get(ApiConfig.staffCheckInReport(eventId));
      if (response != null && response['success'] == true && response['data'] is Map) {
        return Map<String, dynamic>.from(response['data'] as Map);
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  /// Get events available for Direct Booking at the counter (POS)
  Future<List<Map<String, dynamic>>> getDirectBookingEvents() async {
    try {
      final response = await ApiClient().get(ApiConfig.staffDirectBookingEvents);
      if (response != null && response['success'] == true && response['data'] is List) {
        return (response['data'] as List)
            .where((item) => item is Map)
            .map((item) => Map<String, dynamic>.from(item as Map))
            .toList();
      }
      return [];
    } catch (_) {
      return [];
    }
  }

  /// Create direct booking order at the walk-in counter
  Future<Map<String, dynamic>> createDirectBooking({
    required String eventId,
    required String buyerName,
    required String buyerPhone,
    required String buyerEmail,
    String? internalNote,
    required String paymentMethod, // 'cash' | 'bank_transfer'
    required List<Map<String, dynamic>> items, // [{'ticket_type_id': ..., 'quantity': ..., 'session_seat_ids': []}]
  }) async {
    final payload = {
      'event_id': eventId,
      'buyer_name': buyerName,
      'buyer_phone': buyerPhone,
      'buyer_email': buyerEmail,
      'internal_note': internalNote ?? '',
      'payment_method': paymentMethod,
      'items': items,
    };

    final response = await ApiClient().post(ApiConfig.staffDirectBooking, payload);
    return response;
  }

  /// Get direct booking status / receipt
  Future<Map<String, dynamic>?> getDirectBookingStatus(String orderId) async {
    try {
      final response = await ApiClient().get(ApiConfig.staffDirectBookingStatus(orderId));
      if (response != null && response['success'] == true && response['data'] is Map) {
        return Map<String, dynamic>.from(response['data'] as Map);
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  /// Get list of events assigned to this staff member
  Future<List<Map<String, dynamic>>> getAssignedEvents() async {
    try {
      final response = await ApiClient().get(ApiConfig.staffAssignedEvents);
      if (response != null && response['success'] == true && response['data'] is List) {
        return (response['data'] as List)
            .where((item) => item is Map)
            .map((item) => Map<String, dynamic>.from(item as Map))
            .toList();
      }
      return [];
    } catch (_) {
      return [];
    }
  }

  /// Check if the staff has active or upcoming events assigned
  Future<bool> hasActiveOrUpcomingEvents([DateTime? referenceTime]) async {
    try {
      final events = await getAssignedEvents();
      return checkHasActiveOrUpcomingEvents(events, referenceTime: referenceTime);
    } catch (_) {
      return false;
    }
  }

  static bool checkHasActiveOrUpcomingEvents(
    List<Map<String, dynamic>> events, {
    DateTime? referenceTime,
  }) {
    if (events.isEmpty) {
      return false;
    }

    final now = referenceTime ?? DateTime.now();
    for (final item in events) {
      final endTimeStr = item['end_time']?.toString();
      final startTimeStr = item['start_time']?.toString();

      final endTime = endTimeStr != null ? DateTime.tryParse(endTimeStr) : null;
      final startTime = startTimeStr != null ? DateTime.tryParse(startTimeStr) : null;
      final effectiveEnd = endTime ?? startTime;

      if (effectiveEnd == null || !effectiveEnd.isBefore(now)) {
        return true;
      }
    }
    return false;
  }
}
