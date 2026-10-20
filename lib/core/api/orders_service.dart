import 'api_client.dart';
import 'api_config.dart';

class OrderAttendeeInput {
  final String ticketTypeId;
  final String? sessionSeatId;
  final String name;
  final String email;

  OrderAttendeeInput({
    required this.ticketTypeId,
    this.sessionSeatId,
    required this.name,
    required this.email,
  });

  Map<String, dynamic> toJson() => {
        'ticket_type_id': ticketTypeId,
        if (sessionSeatId != null) 'session_seat_id': sessionSeatId,
        'name': name,
        'email': email,
      };
}

class OrderItemInput {
  final String ticketTypeId;
  final int quantity;
  final List<String> sessionSeatIds;

  OrderItemInput({
    required this.ticketTypeId,
    required this.quantity,
    this.sessionSeatIds = const [],
  });

  Map<String, dynamic> toJson() => {
        'ticket_type_id': ticketTypeId,
        'quantity': quantity,
        'session_seat_ids': sessionSeatIds,
      };
}

class OrdersService {
  static final OrdersService _instance = OrdersService._internal();
  factory OrdersService() => _instance;
  OrdersService._internal();

  Future<Map<String, dynamic>> checkoutOrder({
    required String eventId,
    required String buyerName,
    required String buyerEmail,
    String? buyerPhone,
    String? promoCode,
    bool eventTermsAccepted = true,
    List<OrderAttendeeInput> attendees = const [],
    required List<OrderItemInput> items,
  }) async {
    final payload = {
      'event_id': eventId,
      'buyer_name': buyerName,
      'buyer_email': buyerEmail,
      if (buyerPhone != null && buyerPhone.isNotEmpty) 'buyer_phone': buyerPhone,
      if (promoCode != null && promoCode.isNotEmpty) 'promo_code': promoCode,
      'event_terms_accepted': eventTermsAccepted,
      'attendees': attendees.map((a) => a.toJson()).toList(),
      'items': items.map((i) => i.toJson()).toList(),
    };

    final response = await ApiClient().post(ApiConfig.checkout, payload);
    if (response['success'] == true && response['data'] != null) {
      return {
        'success': true,
        'message': response['message'] ?? 'Tạo đơn đặt vé thành công',
        'data': response['data'],
      };
    }
    return {
      'success': false,
      'message': response['message'] ?? 'Không thể tạo đơn hàng',
      'error': response['error'],
    };
  }

  Future<Map<String, dynamic>> getOrderStatus(String orderId) async {
    final response = await ApiClient().get(ApiConfig.orderStatus(orderId));
    if (response['success'] == true && response['data'] != null) {
      return {
        'success': true,
        'data': response['data'],
      };
    }
    return {
      'success': false,
      'message': response['message'] ?? 'Không thể kiểm tra trạng thái đơn hàng',
    };
  }

  Future<Map<String, dynamic>> cancelOrder(String orderId) async {
    final response = await ApiClient().post(ApiConfig.cancelOrder(orderId), {});
    if (response['success'] == true) {
      return {
        'success': true,
        'message': response['message'] ?? 'Đã hủy đơn hàng',
      };
    }
    return {
      'success': false,
      'message': response['message'] ?? 'Không thể hủy đơn hàng',
    };
  }

  Future<List<Map<String, dynamic>>> getAvailablePromotions(String eventId) async {
    try {
      final response = await ApiClient().get(ApiConfig.availablePromotions(eventId));
      if (response['success'] == true && response['data'] is List) {
        return List<Map<String, dynamic>>.from(response['data']);
      }
    } catch (_) {}
    return [];
  }
}
