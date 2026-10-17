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
      return list.map((e) => TicketModel.fromJson(e)).toList();
    }

    // Fallback demonstration mock list for testing customer UI
    return [
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
        attendeeName: 'Lê Hoàng Nam',
        attendeeEmail: 'nam.le@eventhub.vn',
        venue: TicketVenueModel(
          name: 'SECC Exhibition Center',
          addressLine: '799 Nguyễn Văn Linh',
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
        checkInTime: DateTime.now().subtract(const Duration(days: 2, hours: 1)).toIso8601String(),
        venue: TicketVenueModel(
          name: 'Hard Rock Cafe',
          addressLine: '39 Lê Duẩn',
          district: 'Quận 1',
          city: 'TP. Hồ Chí Minh',
        ),
      ),
    ];
  }

  Future<TicketModel?> getTicketDetail(String ticketId) async {
    final response = await ApiClient().get(ApiConfig.ticketDetail(ticketId));
    if (response['success'] == true && response['data'] != null) {
      return TicketModel.fromJson(response['data']);
    }
    // Fallback
    final list = await getMyTickets();
    try {
      return list.firstWhere((t) => t.ticketId == ticketId);
    } catch (_) {
      return list.isNotEmpty ? list.first : null;
    }
  }
}
