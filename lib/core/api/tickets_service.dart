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
    return [];
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
    return null;
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
