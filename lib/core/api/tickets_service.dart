import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/ticket_model.dart';
import 'api_client.dart';
import 'api_config.dart';

class TicketsService {
  static final TicketsService _instance = TicketsService._internal();
  factory TicketsService() => _instance;
  TicketsService._internal();

  Future<List<TicketModel>> getMyTickets({String? status}) async {
    final Map<String, String> queryParams = {};
    if (status != null && status != 'ALL' && status.isNotEmpty) {
      queryParams['status'] = status;
    }

    final response = await ApiClient().get(ApiConfig.myTickets, queryParams: queryParams);
    if (response['success'] == true && response['data'] != null) {
      final List list = response['data'] is List ? response['data'] : [];
      final tickets = list.map((e) => TicketModel.fromJson(e)).toList();
      _sortTickets(tickets);
      return tickets;
    }

    // Fallback demonstration mock list for testing customer UI
    final mockList = [
      TicketModel(
        ticketId: 't-101',
        ticketCode: 'TICK-NEON-8842',
        qrCode: 'TICK-NEON-8842',
        eventId: 'evt-1',
        eventName: 'Neon Horizon Festival 2025',
        ticketType: 'VIP Phase 1',
        seatName: 'Zone A - Row 02',
        sessionTime: DateTime.now().add(const Duration(days: 3)).toIso8601String(),
        status: 'VALID',
        price: 450000,
        originalPrice: 500000,
        attendeeName: 'Lê Hoàng Nam',
        attendeeEmail: 'nam.le@eventhub.vn',
        attendeePhone: '0901234567',
        orderCode: 'ORD-882190',
        venue: TicketVenueModel(
          name: 'SECC Exhibition Center',
          addressLine: '799 Nguyễn Văn Linh',
          ward: 'Tân Phú',
          district: 'Quận 7',
          city: 'TP. Hồ Chí Minh',
        ),
      ),
      TicketModel(
        ticketId: 't-102',
        ticketCode: 'TICK-INDI-1290',
        qrCode: 'TICK-INDI-1290',
        eventId: 'evt-2',
        eventName: 'The Nocturnal Acoustic Echoes',
        ticketType: 'Standard Access',
        seatName: 'Free Standing',
        sessionTime: DateTime.now().subtract(const Duration(days: 2)).toIso8601String(),
        status: 'USED',
        price: 250000,
        attendeeName: 'Lê Hoàng Nam',
        attendeeEmail: 'nam.le@eventhub.vn',
        attendeePhone: '0901234567',
        orderCode: 'ORD-774011',
        checkInTime: DateTime.now().subtract(const Duration(days: 2, hours: 1)).toIso8601String(),
        venue: TicketVenueModel(
          name: 'Hard Rock Cafe',
          addressLine: '39 Lê Duẩn',
          district: 'Quận 1',
          city: 'TP. Hồ Chí Minh',
        ),
      ),
    ];

    if (status != null && status != 'ALL') {
      return mockList.where((t) => t.status == status).toList();
    }
    return mockList;
  }

  void _sortTickets(List<TicketModel> tickets) {
    tickets.sort((a, b) {
      if (a.statusRank != b.statusRank) {
        return a.statusRank.compareTo(b.statusRank);
      }
      final timeA = a.sessionTime != null ? DateTime.tryParse(a.sessionTime!)?.millisecondsSinceEpoch ?? 0 : 0;
      final timeB = b.sessionTime != null ? DateTime.tryParse(b.sessionTime!)?.millisecondsSinceEpoch ?? 0 : 0;
      if (timeA != 0 && timeB != 0) {
        if (a.isValid) {
          return timeA.compareTo(timeB); // Nearest upcoming first
        }
        return timeB.compareTo(timeA); // Most recent first for past
      }
      return b.ticketCode.compareTo(a.ticketCode);
    });
  }

  Future<TicketModel?> getTicketDetail(String ticketId) async {
    final response = await ApiClient().get(ApiConfig.ticketDetail(ticketId));
    if (response['success'] == true && response['data'] != null) {
      return TicketModel.fromJson(response['data']);
    }
    // Fallback to local list
    final list = await getMyTickets();
    try {
      return list.firstWhere((t) => t.ticketId == ticketId);
    } catch (_) {
      return list.isNotEmpty ? list.first : null;
    }
  }

  /// Downloads the official vector SVG ticket from backend API
  Future<Map<String, dynamic>> downloadTicketSvg(String ticketId) async {
    try {
      final token = ApiClient().authToken;
      final uri = Uri.parse('${ApiConfig.baseUrl}${ApiConfig.ticketDownload(ticketId)}');
      final headers = <String, String>{
        'Accept': 'image/svg+xml, application/json, text/plain, */*',
      };
      if (token != null && token.isNotEmpty) {
        headers['Authorization'] = 'Bearer $token';
      }

      final response = await http.get(uri, headers: headers);
      if (response.statusCode >= 200 && response.statusCode < 300) {
        final svgContent = utf8.decode(response.bodyBytes);
        return {
          'success': true,
          'content': svgContent,
          'bytes': response.bodyBytes,
          'fileName': 'ticket_$ticketId.svg',
        };
      }

      return {
        'success': false,
        'message': 'Không thể tải vé từ máy chủ (${response.statusCode})',
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Lỗi kết nối khi tải vé: $e',
      };
    }
  }
}
