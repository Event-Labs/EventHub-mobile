import '../models/ticket_model.dart';
import 'api_client.dart';
import 'api_config.dart';

class StaffService {
  static final StaffService _instance = StaffService._internal();
  factory StaffService() => _instance;
  StaffService._internal();

  /// Check-in ticket using QR code payload (raw string from camera or input)
  Future<Map<String, dynamic>> checkInByQr(String qrCode, {String? gate}) async {
    try {
      final response = await ApiClient().post(ApiConfig.staffCheckInQr, {
        'code': qrCode,
        'qr_code': qrCode,
        'gate': gate ?? 'GATE 01',
      });

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
          'raw': response['data'],
        };
      }

      return {
        'success': false,
        'message': response?['message'] ?? 'Mã vé $qrCode không hợp lệ hoặc vé không thể soát.',
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Lỗi kết nối khi quét vé: $e',
      };
    }
  }

  /// Verify QR without completing check-in (preview ticket info)
  Future<Map<String, dynamic>> verifyQr(String qrCode) async {
    try {
      final response = await ApiClient().post(ApiConfig.staffVerifyQr, {
        'code': qrCode,
        'qr_code': qrCode,
      });

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
          'raw': response['data'],
        };
      }
      return {
        'success': false,
        'message': response?['message'] ?? 'Không tìm thấy thông tin vé!',
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

      return {
        'success': false,
        'message': patchResponse?['message'] ?? 'Không thể check-in vé này!',
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
