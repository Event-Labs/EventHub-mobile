import '../models/ticket_model.dart';
import 'api_client.dart';
import 'api_config.dart';

class TicketsService {
  static final TicketsService _instance = TicketsService._internal();
  factory TicketsService() => _instance;
  TicketsService._internal();

  Future<List<TicketModel>> getMyTickets() async {
    final response = await ApiClient().get(ApiConfig.myTickets);
    if (response['success'] == true && response['data'] != null) {
      final List list = response['data'];
      return list.map((e) => TicketModel.fromJson(e)).toList();
    }

    // Fallback demonstration mock list for testing customer UI
    return [
      TicketModel(
        ticketId: 't-101',
        ticketCode: 'TICK-NEON-8842',
        eventName: 'Neon Horizon Festival 2025',
        ticketType: 'VIP Phase 1',
        seatName: 'Zone A - Row 02',
        sessionTime: '28/12/2025 • 18:00',
        status: 'AVAILABLE',
        price: 450000,
        customerName: 'Lê Hoàng Nam',
        customerEmail: 'nam.le@eventhub.vn',
      ),
      TicketModel(
        ticketId: 't-102',
        ticketCode: 'TICK-INDI-1290',
        eventName: 'The Nocturnal Acoustic Echoes',
        ticketType: 'Standard Access',
        seatName: 'Free Standing',
        sessionTime: '03/01/2026 • 20:00',
        status: 'USED',
        price: 250000,
        customerName: 'Lê Hoàng Nam',
        checkInTime: '03/01/2026 19:45',
      ),
    ];
  }

  Future<Map<String, dynamic>> createOrder({
    required String eventId,
    required String ticketTypeId,
    required int quantity,
    String? promotionCode,
  }) async {
    final response = await ApiClient().post(ApiConfig.orders, {
      'event_id': eventId,
      'ticket_type_id': ticketTypeId,
      'quantity': quantity,
      'promotion_code': promotionCode,
    });

    if (response['success'] == true) {
      return {
        'success': true,
        'message': response['message'] ?? 'Đặt vé thành công!',
        'order': response['data'],
      };
    }
    return {'success': false, 'message': response['message'] ?? 'Không thể đặt vé'};
  }
}
