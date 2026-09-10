import '../models/ticket_model.dart';
import 'api_client.dart';
import 'api_config.dart';

class StaffService {
  static final StaffService _instance = StaffService._internal();
  factory StaffService() => _instance;
  StaffService._internal();

  Future<Map<String, dynamic>> checkInByQr(String qrCode) async {
    final response = await ApiClient().post(ApiConfig.staffCheckInQr, {
      'qr_code': qrCode,
      'gate': 'GATE 02',
    });

    if (response['success'] == true) {
      final ticketData = response['data']?['ticket'] ?? response['data'];
      TicketModel? ticket;
      if (ticketData != null) {
        ticket = TicketModel.fromJson(ticketData);
      }
      return {
        'success': true,
        'message': response['message'] ?? 'Check-in thành công!',
        'ticket': ticket,
      };
    }

    return {
      'success': false,
      'message': response['message'] ?? 'Vé không hợp lệ hoặc đã được sử dụng!',
    };
  }

  Future<List<TicketModel>> searchTickets(String query) async {
    final response = await ApiClient().post(ApiConfig.staffSearchTickets, {
      'query': query,
    });

    if (response['success'] == true && response['data'] != null) {
      final List list = response['data'];
      return list.map((e) => TicketModel.fromJson(e)).toList();
    }

    // Mock fallback list for search testing
    return [
      TicketModel(
        ticketId: 't-101',
        ticketCode: 'TICK-NEON-8842',
        eventName: 'Neon Horizon Festival 2025',
        ticketType: 'VIP Zone A',
        seatName: 'Seat A-12',
        status: 'AVAILABLE',
        customerName: 'Lê Hoàng Nam',
        customerEmail: 'nam.le@eventhub.vn',
        price: 450000,
      ),
      TicketModel(
        ticketId: 't-102',
        ticketCode: 'TICK-BASS-4921',
        eventName: 'Sub-Zero Bass Fest',
        ticketType: 'Fast Pass',
        seatName: 'GA - Standing',
        status: 'USED',
        customerName: 'Trần Thị Thu',
        customerEmail: 'thu.tran@gmail.com',
        price: 380000,
      ),
    ];
  }

  Future<Map<String, dynamic>> manualCheckIn(String ticketId) async {
    final response = await ApiClient().patch('/staff/tickets/$ticketId/check-in', {
      'gate': 'GATE 02',
    });

    if (response['success'] == true) {
      return {'success': true, 'message': 'Check-in thành công!'};
    }
    return {'success': false, 'message': response['message'] ?? 'Không thể check-in vé này'};
  }
}
