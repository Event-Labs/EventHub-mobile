import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../models/ticket_model.dart';
import 'api_client.dart';
import 'api_config.dart';

class StaffService {
  static final StaffService _instance = StaffService._internal();
  factory StaffService() => _instance;
  StaffService._internal();

  static const List<String> acceptedQrTypes = [
    'EVENTHUB_TICKET',
    'EH_TICKET',
    'EHT',
    'EH',
  ];

  static String _firstNonEmpty(List<dynamic> values) {
    for (final v in values) {
      if (v != null) {
        final s = v.toString().trim();
        if (s.isNotEmpty) return s;
      }
    }
    return '';
  }

  static String normalizeRawQrInput(String rawCode) {
    var clean = rawCode.trim();
    if (clean.startsWith('\uFEFF')) {
      clean = clean.substring(1).trim();
    }
    if (clean.length >= 2 && clean.startsWith('"') && clean.endsWith('"') && !clean.contains('{')) {
      clean = clean.substring(1, clean.length - 1).trim();
    }
    return clean;
  }

  /// Parse QR code string: supports compact JSON ({"type":"EVENTHUB_TICKET","ticket_code":...}
  /// or shorthand {"type":"EHT","t":...}), legacy 6-field JSON, URLs, and plain ticket codes.
  static Map<String, String> parseQrPayload(String rawCode) {
    final clean = normalizeRawQrInput(rawCode);

    if (clean.startsWith('http://') || clean.startsWith('https://')) {
      try {
        final uri = Uri.parse(clean);
        final codeParam = _firstNonEmpty([
          uri.queryParameters['code'],
          uri.queryParameters['ticket_code'],
          uri.queryParameters['ticketCode'],
          uri.queryParameters['t'],
          uri.queryParameters['qr_code'],
          uri.queryParameters['qrCode'],
          uri.queryParameters['ticket_id'],
          uri.queryParameters['ticketId'],
        ]);
        if (codeParam.isNotEmpty) {
          final ticketIdParam = _firstNonEmpty([
            uri.queryParameters['ticket_id'],
            uri.queryParameters['ticketId'],
          ]);
          return {
            'format': 'url',
            'is_valid_type': 'true',
            'effective_code': codeParam,
            'ticket_code': codeParam,
            'ticket_id': ticketIdParam,
            'qr_code': codeParam,
          };
        }
      } catch (_) {}
    }

    if ((clean.startsWith('{') && clean.endsWith('}')) || (clean.startsWith('{"') && clean.contains('}'))) {
      try {
        final decoded = jsonDecode(clean);
        if (decoded is Map) {
          final type = _firstNonEmpty([decoded['type']]);
          final ticketCode = _firstNonEmpty([
            decoded['ticket_code'],
            decoded['ticketCode'],
            decoded['code'],
            decoded['t'],
          ]);
          final ticketId = _firstNonEmpty([
            decoded['ticket_id'],
            decoded['ticketId'],
            decoded['id'],
          ]);
          final qrCodeVal = _firstNonEmpty([
            decoded['qr_code'],
            decoded['qrCode'],
          ]);
          final eventId = _firstNonEmpty([
            decoded['event_id'],
            decoded['eventId'],
          ]);
          final sessionId = _firstNonEmpty([
            decoded['session_id'],
            decoded['sessionId'],
          ]);
          final effective = ticketCode.isNotEmpty
              ? ticketCode
              : (qrCodeVal.isNotEmpty ? qrCodeVal : (ticketId.isNotEmpty ? ticketId : clean));
          final isValidType = type.isEmpty || acceptedQrTypes.contains(type.toUpperCase());
          return {
            'format': 'json',
            'type': type,
            'is_valid_type': isValidType ? 'true' : 'false',
            'event_id': eventId,
            'session_id': sessionId,
            'effective_code': effective,
            'ticket_code': ticketCode.isNotEmpty ? ticketCode : effective,
            'ticket_id': ticketId,
            'qr_code': qrCodeVal.isNotEmpty ? qrCodeVal : effective,
          };
        }
      } catch (_) {}
    }

    return {
      'format': 'plain',
      'is_valid_type': 'true',
      'effective_code': clean,
      'ticket_code': clean,
      'ticket_id': '',
      'qr_code': clean,
    };
  }

  /// Sanitize error messages so that clear Vietnamese messages from the backend are preserved
  /// while raw JSON or technical stack traces are safely cleaned up.
  static String sanitizeStaffMessage(dynamic rawMsg, {String? defaultMsg}) {
    if (rawMsg == null) return defaultMsg ?? 'Không tìm thấy thông tin vé!';
    final str = rawMsg.toString().trim();
    if (str.isEmpty) return defaultMsg ?? 'Không tìm thấy thông tin vé!';

    // If message is or contains JSON, parse message property or sanitize
    if ((str.startsWith('{') && str.endsWith('}')) || str.contains('"errorCode"') || str.contains('"message":')) {
      try {
        final decoded = jsonDecode(str);
        if (decoded is Map && decoded['message'] != null) {
          return sanitizeStaffMessage(decoded['message'], defaultMsg: defaultMsg);
        }
      } catch (_) {}
    }

    // Preserve complete Vietnamese backend messages verbatim (including subscription guards, QR mismatch, etc.)
    final hasVietnameseDiacritics = RegExp(
      r'[àáạảãâầấậẩẫăằắặẳẵèéẹẻẽêềếệểễìíịỉĩòóọỏõôồốộổỗơờớợởỡùúụủũưừứựửữỳýỵỷỹđ]',
      caseSensitive: false,
    ).hasMatch(str);

    if (str.startsWith('Vé') ||
        str.startsWith('Mã QR') ||
        str.startsWith('QR') ||
        str.startsWith('Nhân') ||
        str.startsWith('Staff') ||
        str.startsWith('Sự kiện') ||
        str.startsWith('Không tìm thấy') ||
        str.startsWith('Gói dịch vụ') ||
        str.startsWith('Vui lòng') ||
        (hasVietnameseDiacritics &&
            !str.contains('{') &&
            !str.contains('Exception') &&
            !str.contains('Error:'))) {
      return str;
    }

    final lower = str.toLowerCase();
    if (lower.contains('not found') || lower.contains('không tìm thấy') || lower.contains('ticket_not_found')) {
      return 'Không tìm thấy vé trong hệ thống hoặc mã vé không tồn tại.';
    }
    if (lower.contains('already checked') || lower.contains('đã check-in') || lower.contains('already_used')) {
      return 'Vé này đã được check-in trước đó.';
    }
    if (lower.contains('auth_required') || lower.contains('not authorized') || lower.contains('không có quyền') || lower.contains('forbidden')) {
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

  /// Returns true when backend rejected the request due to missing/expired/invalid JWT.
  static bool isAuthErrorResponse(dynamic response) {
    if (response is! Map) return false;
    final status = response['statusCode'];
    if (status == 401) return true;
    final errorCode = response['errorCode']?.toString() ?? '';
    return errorCode == 'AUTH_REQUIRED' ||
        errorCode == 'AUTH_INVALID_TOKEN' ||
        errorCode == 'AUTH_EXPIRED_TOKEN' ||
        errorCode == 'AUTH_USER_NOT_FOUND';
  }

  /// Returns true when backend rejected the request due to missing role/event permissions.
  static bool isForbiddenErrorResponse(dynamic response) {
    if (response is! Map) return false;
    final status = response['statusCode'];
    if (status == 403) return true;
    final errorCode = response['errorCode']?.toString() ?? '';
    return errorCode == 'AUTH_FORBIDDEN' || errorCode == 'FORBIDDEN_ACTION';
  }

  /// Prepare QR payload string to send to Web backend (`{ qrCode }`).
  /// Keeps JSON intact so backend asserts `type`, `eventId`, and `sessionId`; extracts query code for URLs.
  static String _prepareQrForBackend(String rawCode, Map<String, String> parsed) {
    final clean = normalizeRawQrInput(rawCode);
    if (parsed['format'] == 'url' && (parsed['effective_code'] ?? '').isNotEmpty) {
      return parsed['effective_code']!;
    }
    return clean;
  }

  /// Check-in ticket using QR code payload (matches web checkInTicketByQr({ qrCode }))
  Future<Map<String, dynamic>> checkInByQr(String qrCode, {String? gate}) async {
    try {
      final clean = normalizeRawQrInput(qrCode);
      final parsed = parseQrPayload(clean);
      final effectiveCode = parsed['effective_code'] ?? clean;

      if (parsed['format'] == 'json' && parsed['is_valid_type'] == 'false') {
        return {
          'success': false,
          'message': 'QR không đúng định dạng vé EventHub.',
          'raw_message': 'QR không đúng định dạng vé EventHub.',
          'errorCode': 'INVALID_INPUT',
        };
      }

      final qrPayloadToSend = _prepareQrForBackend(clean, parsed);
      final payload = <String, dynamic>{
        'qrCode': qrPayloadToSend,
        if (gate != null && gate.isNotEmpty) 'gate': gate,
      };

      final response = await ApiClient().post(ApiConfig.staffCheckInQr, payload);

      if (isAuthErrorResponse(response)) {
        return {
          'success': false,
          'requiresLogin': true,
          'message': 'Phiên đăng nhập đã hết hạn. Vui lòng đăng nhập lại.',
          'raw_message': response?['message']?.toString(),
          'errorCode': response?['errorCode'],
          'statusCode': response?['statusCode'] ?? 401,
        };
      }

      if (response != null && response['success'] == true) {
        final rawData = response['data'];
        final ticketData = (rawData is Map && rawData['ticket'] is Map)
            ? rawData['ticket']
            : rawData;
        TicketModel? ticket;
        if (ticketData != null && ticketData is Map) {
          try {
            ticket = TicketModel.fromJson(Map<String, dynamic>.from(ticketData));
          } catch (e, st) {
            debugPrint('[StaffService] checkInByQr parse TicketModel error: $e\n$st');
          }
        }
        return {
          'success': true,
          'message': response['message'] ?? 'Check-in thành công!',
          'ticket': ticket,
          'ticket_code': ticket?.ticketCode ?? (parsed['ticket_code']?.isNotEmpty == true ? parsed['ticket_code'] : effectiveCode),
          'raw': response['data'],
        };
      }

      final rawErrorMsg = response?['message'] ?? response?['error']?['message'];
      final errorMsg = sanitizeStaffMessage(
        rawErrorMsg,
        defaultMsg: 'Mã vé không hợp lệ hoặc vé không thể soát.',
      );
      return {
        'success': false,
        'message': errorMsg,
        'raw_message': rawErrorMsg?.toString(),
        'errorCode': response?['errorCode'],
        'statusCode': response?['statusCode'],
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Lỗi kết nối khi quét vé: $e',
      };
    }
  }

  /// Verify QR without completing check-in (matches web verifyStaffTicketByQr({ qrCode }))
  Future<Map<String, dynamic>> verifyQr(String qrCode) async {
    try {
      final clean = normalizeRawQrInput(qrCode);
      final parsed = parseQrPayload(clean);
      final effectiveCode = parsed['effective_code'] ?? clean;

      if (parsed['format'] == 'json' && parsed['is_valid_type'] == 'false') {
        return {
          'success': false,
          'message': 'QR không đúng định dạng vé EventHub.',
          'raw_message': 'QR không đúng định dạng vé EventHub.',
          'errorCode': 'INVALID_INPUT',
        };
      }

      // Web contract sends { qrCode: value } directly so backend extractQrTicketPayload + assertQrMatchesTicket
      // verify type, ticketRef, eventId, and sessionId cleanly.
      final qrPayloadToSend = _prepareQrForBackend(clean, parsed);
      final payload = <String, dynamic>{
        'qrCode': qrPayloadToSend,
      };

      final response = await ApiClient().post(ApiConfig.staffVerifyQr, payload);

      if (isAuthErrorResponse(response)) {
        return {
          'success': false,
          'requiresLogin': true,
          'message': 'Phiên đăng nhập đã hết hạn. Vui lòng đăng nhập lại.',
          'raw_message': response?['message']?.toString(),
          'errorCode': response?['errorCode'],
          'statusCode': response?['statusCode'] ?? 401,
          'ticket_code': parsed['ticket_code']?.isNotEmpty == true ? parsed['ticket_code'] : null,
        };
      }

      if (response != null && response['success'] == true && response['data'] != null) {
        final rawData = response['data'];
        final ticketData = (rawData is Map && rawData['ticket'] is Map)
            ? rawData['ticket']
            : rawData;
        TicketModel? ticket;
        if (ticketData != null && ticketData is Map) {
          try {
            ticket = TicketModel.fromJson(Map<String, dynamic>.from(ticketData));
          } catch (e, st) {
            debugPrint('[StaffService] verifyQr parse TicketModel error: $e\n$st');
          }
        }
        if (ticket == null) {
          return {
            'success': false,
            'message': 'Dữ liệu vé trả về từ máy chủ không đúng định dạng.',
            'raw_message': response['message']?.toString(),
            'ticket_code': parsed['ticket_code']?.isNotEmpty == true ? parsed['ticket_code'] : effectiveCode,
          };
        }
        return {
          'success': true,
          'message': response['message'] ?? 'Vé hợp lệ!',
          'ticket': ticket,
          'ticket_code': ticket.ticketCode.isNotEmpty
              ? ticket.ticketCode
              : (parsed['ticket_code']?.isNotEmpty == true ? parsed['ticket_code'] : effectiveCode),
          'raw': response['data'],
        };
      }

      final rawErrorMsg = response?['message'] ?? response?['error']?['message'];
      final errorMsg = sanitizeStaffMessage(
        rawErrorMsg,
        defaultMsg: 'Không tìm thấy thông tin vé hoặc mã QR không tồn tại.',
      );
      return {
        'success': false,
        'message': errorMsg,
        'raw_message': rawErrorMsg?.toString(),
        'errorCode': response?['errorCode'],
        'statusCode': response?['statusCode'],
        'ticket_code': parsed['ticket_code']?.isNotEmpty == true ? parsed['ticket_code'] : null,
      };
    } catch (e) {
      return {'success': false, 'message': 'Lỗi xác thực vé: $e'};
    }
  }

  /// Extract list of tickets from backend response payload
  static List<TicketModel> extractTicketsFromResponse(dynamic data) {
    final List list = (data is Map && data['tickets'] is List)
        ? (data['tickets'] as List)
        : (data is List ? data : []);
    final tickets = <TicketModel>[];
    for (final item in list) {
      if (item is Map) {
        try {
          tickets.add(TicketModel.fromJson(Map<String, dynamic>.from(item)));
        } catch (e, st) {
          debugPrint('[StaffService] TicketModel parse error: $e\n$st');
        }
      }
    }
    return tickets;
  }

  /// Build Web-compatible POST /staff/tickets/search payload
  static Map<String, dynamic> buildSearchPayload({
    String? query,
    String? eventId,
    String? ticketCode,
    String? buyerName,
    String? buyerEmail,
    String? buyerPhone,
  }) {
    final effectiveEventId = (eventId ?? '').trim();
    final payload = <String, dynamic>{
      if (effectiveEventId.isNotEmpty) 'eventId': effectiveEventId,
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
      if (rawQ.startsWith('{') || rawQ.startsWith('http://') || rawQ.startsWith('https://')) {
        final parsedQr = parseQrPayload(rawQ);
        final extractedCode = parsedQr['ticket_code']?.isNotEmpty == true
            ? parsedQr['ticket_code']!
            : (parsedQr['effective_code'] ?? rawQ);
        payload['ticketCode'] = extractedCode;
      } else if (rawQ.contains('@')) {
        payload['buyerEmail'] = rawQ;
      } else if (RegExp(r'^\+?[0-9\s\-]{8,15}$').hasMatch(rawQ)) {
        payload['buyerPhone'] = rawQ.replaceAll(RegExp(r'[\s\-]'), '');
      } else if (rawQ.contains('-') ||
          rawQ.contains('_') ||
          RegExp(r'^(TK|TICK|EH)', caseSensitive: false).hasMatch(rawQ) ||
          (!rawQ.contains(' ') && RegExp(r'^[A-Z0-9]{6,}$').hasMatch(rawQ))) {
        payload['ticketCode'] = rawQ;
      } else {
        payload['buyerName'] = rawQ;
      }
    }

    return payload;
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

  /// Detailed search tickets with filters returning structured status + error information
  Future<Map<String, dynamic>> searchTicketsResult({
    String? query,
    String? eventId,
    String? ticketCode,
    String? buyerName,
    String? buyerEmail,
    String? buyerPhone,
    bool allowEmptyEventId = false,
  }) async {
    final effectiveEventId = (eventId ?? '').trim();
    if (effectiveEventId.isEmpty && !allowEmptyEventId) {
      return {
        'success': true,
        'tickets': <TicketModel>[],
      };
    }

    final payload = buildSearchPayload(
      query: query,
      eventId: effectiveEventId,
      ticketCode: ticketCode,
      buyerName: buyerName,
      buyerEmail: buyerEmail,
      buyerPhone: buyerPhone,
    );

    if (payload.isEmpty) {
      return {
        'success': true,
        'tickets': <TicketModel>[],
      };
    }

    try {
      final response = await ApiClient().post(ApiConfig.staffSearchTickets, payload);

      if (isAuthErrorResponse(response)) {
        return {
          'success': false,
          'requiresLogin': true,
          'tickets': <TicketModel>[],
          'message': 'Phiên đăng nhập đã hết hạn. Vui lòng đăng nhập lại.',
          'raw_message': response?['message']?.toString(),
          'errorCode': response?['errorCode'],
          'statusCode': response?['statusCode'] ?? 401,
        };
      }

      if (response != null && response['success'] == true) {
        final tickets = extractTicketsFromResponse(response['data']);

        // If generic text search returned 0 items with buyerName, also try ticketCode (e.g. arbitrary code without dashes)
        final rawQ = query?.trim() ?? '';
        if (tickets.isEmpty &&
            rawQ.isNotEmpty &&
            payload.containsKey('buyerName') &&
            !rawQ.contains(' ') &&
            !rawQ.contains('@') &&
            !RegExp(r'^\+?[0-9\s\-]{8,15}$').hasMatch(rawQ)) {
          final fallbackPayload = <String, dynamic>{
            if (effectiveEventId.isNotEmpty) 'eventId': effectiveEventId,
            'ticketCode': rawQ,
          };
          final fbResponse = await ApiClient().post(ApiConfig.staffSearchTickets, fallbackPayload);
          if (fbResponse != null && fbResponse['success'] == true) {
            return {
              'success': true,
              'tickets': extractTicketsFromResponse(fbResponse['data']),
              'raw': fbResponse['data'],
            };
          }
        }

        return {
          'success': true,
          'tickets': tickets,
          'raw': response['data'],
        };
      }

      if (isForbiddenErrorResponse(response)) {
        return {
          'success': false,
          'tickets': <TicketModel>[],
          'message': 'Tài khoản không có quyền xem danh sách vé cho sự kiện này. Hãy thử đăng xuất và đăng nhập lại.',
          'raw_message': response?['message']?.toString(),
          'errorCode': response?['errorCode'],
          'statusCode': response?['statusCode'] ?? 403,
        };
      }

      final rawErrorMsg = response?['message'] ?? response?['error']?['message'];
      return {
        'success': false,
        'tickets': <TicketModel>[],
        'message': sanitizeStaffMessage(
          rawErrorMsg,
          defaultMsg: 'Không thể tải danh sách vé từ máy chủ.',
        ),
        'raw_message': rawErrorMsg?.toString(),
        'errorCode': response?['errorCode'],
        'statusCode': response?['statusCode'],
      };
    } catch (e, st) {
      debugPrint('[StaffService] searchTicketsResult error: $e\n$st');
      return {
        'success': false,
        'tickets': <TicketModel>[],
        'message': 'Lỗi kết nối khi truy vấn danh sách vé: $e',
      };
    }
  }

  /// Detailed search tickets with filters (List helper)
  Future<List<TicketModel>> searchTicketsWithFilters({
    String? query,
    String? eventId,
    String? ticketCode,
    String? buyerName,
    String? buyerEmail,
    String? buyerPhone,
    bool allowEmptyEventId = false,
  }) async {
    final res = await searchTicketsResult(
      query: query,
      eventId: eventId,
      ticketCode: ticketCode,
      buyerName: buyerName,
      buyerEmail: buyerEmail,
      buyerPhone: buyerPhone,
      allowEmptyEventId: allowEmptyEventId,
    );
    return (res['tickets'] as List<TicketModel>?) ?? <TicketModel>[];
  }

  /// Fetch single ticket detail for staff (matches Web fetchStaffTicket: GET /staff/tickets/:ticketId)
  Future<Map<String, dynamic>> getStaffTicket(String ticketId) async {
    final cleanId = ticketId.trim();
    if (cleanId.isEmpty) {
      return {
        'success': false,
        'message': 'Thiếu mã định danh vé.',
      };
    }
    try {
      final response = await ApiClient().get(ApiConfig.staffTicketDetail(cleanId));
      if (isAuthErrorResponse(response)) {
        return {
          'success': false,
          'requiresLogin': true,
          'message': 'Phiên đăng nhập đã hết hạn. Vui lòng đăng nhập lại.',
          'raw_message': response?['message']?.toString(),
          'errorCode': response?['errorCode'],
          'statusCode': response?['statusCode'] ?? 401,
        };
      }
      if (response != null && response['success'] == true && response['data'] != null) {
        final rawData = response['data'];
        final ticketData = (rawData is Map && rawData['ticket'] is Map)
            ? rawData['ticket']
            : rawData;
        TicketModel? ticket;
        if (ticketData is Map) {
          ticket = TicketModel.fromJson(Map<String, dynamic>.from(ticketData));
        }
        return {
          'success': ticket != null,
          'ticket': ticket,
          'raw': rawData,
          if (ticket == null) 'message': 'Không thể đọc dữ liệu vé.',
        };
      }
      final rawErrorMsg = response?['message'] ?? response?['error']?['message'];
      return {
        'success': false,
        'message': sanitizeStaffMessage(
          rawErrorMsg,
          defaultMsg: 'Không thể tải thông tin vé.',
        ),
        'raw_message': rawErrorMsg?.toString(),
        'errorCode': response?['errorCode'],
        'statusCode': response?['statusCode'],
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Lỗi kết nối khi tải thông tin vé: $e',
      };
    }
  }

  /// Manual check-in by ticket ID (matches Web checkInStaffTicket: PATCH /staff/tickets/:ticketId/check-in)
  Future<Map<String, dynamic>> manualCheckIn(String ticketId, {String? gate}) async {
    try {
      final patchResponse = await ApiClient().patch(ApiConfig.staffCheckInTicket(ticketId), {
        if (gate != null && gate.isNotEmpty) 'gate': gate,
      });
      if (isAuthErrorResponse(patchResponse)) {
        return {
          'success': false,
          'requiresLogin': true,
          'message': 'Phiên đăng nhập đã hết hạn. Vui lòng đăng nhập lại.',
          'raw_message': patchResponse?['message']?.toString(),
          'errorCode': patchResponse?['errorCode'],
          'statusCode': patchResponse?['statusCode'] ?? 401,
        };
      }
      if (patchResponse != null && patchResponse['success'] == true) {
        final rawData = patchResponse['data'];
        final ticketData = (rawData is Map && rawData['ticket'] is Map)
            ? rawData['ticket']
            : rawData;
        TicketModel? ticket;
        if (ticketData != null && ticketData is Map) {
          try {
            ticket = TicketModel.fromJson(Map<String, dynamic>.from(ticketData));
          } catch (e, st) {
            debugPrint('[StaffService] manualCheckIn parse TicketModel error: $e\n$st');
          }
        }
        return {
          'success': true,
          'message': patchResponse['message'] ?? 'Check-in thành công!',
          'ticket': ticket,
        };
      }

      final rawErrorMsg = patchResponse?['message'] ?? patchResponse?['error']?['message'];
      final errorMsg = sanitizeStaffMessage(
        rawErrorMsg,
        defaultMsg: 'Không thể check-in vé này!',
      );
      return {
        'success': false,
        'message': errorMsg,
        'raw_message': rawErrorMsg?.toString(),
        'errorCode': patchResponse?['errorCode'],
        'statusCode': patchResponse?['statusCode'],
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

  /// Safely extract a list of raw event/assignment maps from various backend response shapes
  static List<dynamic> extractListFromResponse(dynamic response) {
    if (response == null) return [];
    if (response is List) return response;
    if (response is! Map) return [];

    // If explicit failure and no data property, return empty
    if (response['success'] == false && response['data'] == null && response['events'] == null) {
      return [];
    }

    final data = response['data'];
    if (data is List) {
      return data;
    }
    if (data is Map) {
      final candidates = [
        data['events'],
        data['items'],
        data['assignedEvents'],
        data['assigned_events'],
        data['staffEvents'],
        data['assignments'],
        data['invitations'],
        data['results'],
        data['rows'],
        data['data'],
      ];
      for (final c in candidates) {
        if (c is List) return c;
      }
    }

    final topLevelCandidates = [
      response['events'],
      response['items'],
      response['assignedEvents'],
      response['assigned_events'],
      response['staffEvents'],
      response['assignments'],
      response['invitations'],
      response['results'],
    ];
    for (final c in topLevelCandidates) {
      if (c is List) return c;
    }

    return [];
  }

  /// Normalize any raw event or staff assignment object into a consistent Map<String, dynamic>
  static Map<String, dynamic> normalizeStaffEvent(Map raw) {
    final Map<String, dynamic> item = Map<String, dynamic>.from(raw);
    final nestedEvent = (item['event'] is Map)
        ? Map<String, dynamic>.from(item['event'] as Map)
        : ((item['Event'] is Map)
            ? Map<String, dynamic>.from(item['Event'] as Map)
            : null);

    final normalized = <String, dynamic>{};
    if (nestedEvent != null) {
      normalized.addAll(nestedEvent);
    }
    normalized.addAll(item);

    final eventId = nestedEvent?['id']?.toString() ??
        item['event_id']?.toString() ??
        item['eventId']?.toString() ??
        item['id']?.toString() ??
        '';

    final eventTitle = nestedEvent?['title']?.toString() ??
        nestedEvent?['name']?.toString() ??
        item['title']?.toString() ??
        item['name']?.toString() ??
        'Sự kiện EventHub';

    final eventName = nestedEvent?['name']?.toString() ??
        nestedEvent?['title']?.toString() ??
        item['name']?.toString() ??
        item['title']?.toString() ??
        eventTitle;

    final venueName = nestedEvent?['venue_name']?.toString() ??
        nestedEvent?['venue']?['name']?.toString() ??
        item['venue_name']?.toString() ??
        item['venue']?['name']?.toString() ??
        nestedEvent?['location']?.toString() ??
        item['location']?.toString() ??
        'Địa điểm đang cập nhật';

    final startTime = nestedEvent?['start_time'] ??
        nestedEvent?['startTime'] ??
        nestedEvent?['start_date'] ??
        nestedEvent?['startDate'] ??
        item['start_time'] ??
        item['startTime'] ??
        item['start_date'] ??
        item['startDate'];

    final endTime = nestedEvent?['end_time'] ??
        nestedEvent?['endTime'] ??
        nestedEvent?['end_date'] ??
        nestedEvent?['endDate'] ??
        item['end_time'] ??
        item['endTime'] ??
        item['end_date'] ??
        item['endDate'];

    final gate = item['gate']?.toString() ??
        nestedEvent?['gate']?.toString() ??
        'GATE 01 - Main Entrance';

    final zone = item['zone']?.toString() ??
        nestedEvent?['zone']?.toString() ??
        'Khu vực chính';

    final role = item['role']?.toString() ??
        nestedEvent?['role']?.toString() ??
        'Nhân viên soát vé';

    final status = item['status']?.toString() ??
        nestedEvent?['status']?.toString() ??
        'ACTIVE';

    final bannerUrl = nestedEvent?['banner_url']?.toString() ??
        nestedEvent?['bannerUrl']?.toString() ??
        nestedEvent?['thumbnail_url']?.toString() ??
        nestedEvent?['thumbnailUrl']?.toString() ??
        item['banner_url']?.toString() ??
        item['bannerUrl']?.toString() ??
        item['thumbnail_url']?.toString() ??
        item['thumbnailUrl']?.toString();

    final ticketTypes = nestedEvent?['ticket_types'] ??
        nestedEvent?['ticketTypes'] ??
        item['ticket_types'] ??
        item['ticketTypes'];

    final sessions = nestedEvent?['sessions'] ?? item['sessions'];

    final checkedIn = item['checked_in'] ?? nestedEvent?['checked_in'];
    final totalValid = item['total_valid'] ?? item['total_tickets'] ?? nestedEvent?['total_valid'] ?? nestedEvent?['total_tickets'];
    final remaining = item['remaining'] ?? nestedEvent?['remaining'];
    final checkinStartTime = item['checkin_start_time'] ??
        nestedEvent?['checkin_start_time'] ??
        (sessions is List && sessions.isNotEmpty && sessions.first is Map
            ? sessions.first['checkin_start_time']
            : null);

    normalized['id'] = eventId;
    normalized['assignment_id'] = item['id']?.toString() ?? eventId;
    normalized['title'] = eventTitle;
    normalized['name'] = eventName;
    normalized['venue_name'] = venueName;
    if (startTime != null) normalized['start_time'] = startTime;
    if (endTime != null) normalized['end_time'] = endTime;
    normalized['gate'] = gate;
    normalized['zone'] = zone;
    normalized['role'] = role;
    normalized['status'] = status;
    if (bannerUrl != null) normalized['banner_url'] = bannerUrl;
    if (ticketTypes != null) normalized['ticket_types'] = ticketTypes;
    if (sessions != null) normalized['sessions'] = sessions;
    if (checkedIn != null) normalized['checked_in'] = checkedIn;
    if (totalValid != null) {
      normalized['total_valid'] = totalValid;
      normalized['total_tickets'] = totalValid;
    }
    if (remaining != null) normalized['remaining'] = remaining;
    if (checkinStartTime != null) normalized['checkin_start_time'] = checkinStartTime;

    return normalized;
  }

  static void _collectNormalizedEvents(
    dynamic response,
    List<Map<String, dynamic>> out,
    Set<String> seenKeys,
  ) {
    final list = extractListFromResponse(response);
    for (final raw in list) {
      if (raw is Map) {
        final normalized = normalizeStaffEvent(raw);
        final id = normalized['id']?.toString() ?? '';
        final title = normalized['title']?.toString() ?? '';
        final key = id.isNotEmpty ? id : title;
        if (key.isNotEmpty && !seenKeys.contains(key)) {
          seenKeys.add(key);
          out.add(normalized);
        }
      }
    }
  }

  /// Fetch assigned events for the authenticated staff member with explicit auth/error state
  /// (matches Web fetchAssignedStaffEvents: GET /operations/staff/events).
  Future<Map<String, dynamic>> getAssignedEventsResult() async {
    final List<Map<String, dynamic>> allNormalizedEvents = [];
    final Set<String> seenKeys = {};

    try {
      final response = await ApiClient().get(ApiConfig.staffAssignedEvents);

      if (isAuthErrorResponse(response)) {
        return {
          'success': false,
          'requiresLogin': true,
          'events': <Map<String, dynamic>>[],
          'statusCode': response?['statusCode'] ?? 401,
          'errorCode': response?['errorCode'],
          'message': 'Phiên đăng nhập đã hết hạn. Vui lòng đăng nhập lại.',
        };
      }

      if (isForbiddenErrorResponse(response)) {
        return {
          'success': false,
          'requiresLogin': false,
          'events': <Map<String, dynamic>>[],
          'statusCode': response?['statusCode'] ?? 403,
          'errorCode': response?['errorCode'],
          'message': 'Tài khoản chưa có quyền Nhân sự (STAFF) cho sự kiện này. Hãy thử đăng xuất và đăng nhập lại.',
        };
      }

      if (response != null && response['success'] == true) {
        _collectNormalizedEvents(response, allNormalizedEvents, seenKeys);
        return {
          'success': true,
          'events': allNormalizedEvents,
        };
      }

      // Only fall back to direct-booking events when primary route is not deployed (404)
      if (response?['statusCode'] == 404) {
        final fbResponse = await ApiClient().get(ApiConfig.staffDirectBookingEvents);
        if (fbResponse != null && fbResponse['success'] == true) {
          _collectNormalizedEvents(fbResponse, allNormalizedEvents, seenKeys);
          return {
            'success': true,
            'events': allNormalizedEvents,
          };
        }
      }

      return {
        'success': false,
        'requiresLogin': false,
        'events': <Map<String, dynamic>>[],
        'statusCode': response?['statusCode'],
        'errorCode': response?['errorCode'],
        'message': response?['message']?.toString() ?? 'Không thể tải danh sách sự kiện được phân công.',
      };
    } catch (e) {
      debugPrint('[StaffService] getAssignedEventsResult error: $e');
      return {
        'success': false,
        'requiresLogin': false,
        'events': <Map<String, dynamic>>[],
        'message': 'Lỗi kết nối khi tải sự kiện phân công: $e',
      };
    }
  }

  /// Get list of events assigned to this staff member (matches Web fetchAssignedStaffEvents)
  Future<List<Map<String, dynamic>>> getAssignedEvents() async {
    final res = await getAssignedEventsResult();
    return (res['events'] as List<Map<String, dynamic>>?) ?? [];
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
      final endTimeStr = item['end_time']?.toString() ??
          item['endTime']?.toString() ??
          item['end_date']?.toString() ??
          item['endDate']?.toString() ??
          item['event']?['end_time']?.toString() ??
          item['event']?['endTime']?.toString();

      final startTimeStr = item['start_time']?.toString() ??
          item['startTime']?.toString() ??
          item['start_date']?.toString() ??
          item['startDate']?.toString() ??
          item['event']?['start_time']?.toString() ??
          item['event']?['startTime']?.toString();

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
