import 'api_client.dart';
import 'api_config.dart';

class RefundRequestModel {
  final String id;
  final String? ticketId;
  final String? ticketCode;
  final String? eventTitle;
  final double amount;
  final double refundFee;
  final double refundAmount;
  final String status;
  final String? reason;
  final String? bankName;
  final String? bankAccountNumber;
  final String? bankAccountName;
  final String? createdAt;

  RefundRequestModel({
    required this.id,
    this.ticketId,
    this.ticketCode,
    this.eventTitle,
    this.amount = 0,
    this.refundFee = 0,
    this.refundAmount = 0,
    required this.status,
    this.reason,
    this.bankName,
    this.bankAccountNumber,
    this.bankAccountName,
    this.createdAt,
  });

  factory RefundRequestModel.fromJson(Map<String, dynamic> json) {
    return RefundRequestModel(
      id: json['id']?.toString() ?? '',
      ticketId: json['ticket_id']?.toString(),
      ticketCode: json['ticket_code']?.toString() ?? (json['ticket'] is Map ? json['ticket']['ticket_code']?.toString() : null),
      eventTitle: json['event_title']?.toString() ?? (json['event'] is Map ? json['event']['title']?.toString() : null),
      amount: json['amount'] != null ? double.tryParse(json['amount'].toString()) ?? 0 : 0,
      refundFee: json['refund_fee'] != null ? double.tryParse(json['refund_fee'].toString()) ?? 0 : 0,
      refundAmount: json['refund_amount'] != null ? double.tryParse(json['refund_amount'].toString()) ?? 0 : 0,
      status: json['status']?.toString().toUpperCase() ?? 'PENDING',
      reason: json['reason']?.toString(),
      bankName: json['bank_name']?.toString(),
      bankAccountNumber: json['bank_account_number']?.toString(),
      bankAccountName: json['bank_account_name']?.toString(),
      createdAt: json['created_at']?.toString(),
    );
  }

  String get statusText {
    switch (status) {
      case 'PENDING':
        return 'Chờ xử lý';
      case 'APPROVED':
        return 'Đã chấp thuận';
      case 'REJECTED':
        return 'Bị từ chối';
      case 'COMPLETED':
        return 'Đã hoàn tiền';
      default:
        return status;
    }
  }
}

class RefundsService {
  static final RefundsService _instance = RefundsService._internal();
  factory RefundsService() => _instance;
  RefundsService._internal();

  Future<Map<String, dynamic>> getRefundPreview({String? ticketId, String? orderId}) async {
    final Map<String, String> queryParams = {};
    if (ticketId != null) queryParams['ticket_id'] = ticketId;
    if (orderId != null) queryParams['order_id'] = orderId;

    final response = await ApiClient().get(ApiConfig.refundPreview, queryParams: queryParams);
    if (response['success'] == true && response['data'] != null) {
      return {'success': true, 'data': response['data']};
    }
    return {'success': false, 'message': response['message'] ?? 'Không thể kiểm tra chính sách hoàn tiền'};
  }

  Future<Map<String, dynamic>> submitRefundRequest({
    required String ticketId,
    required String reason,
    required String bankName,
    required String bankAccountNumber,
    required String bankAccountName,
  }) async {
    final response = await ApiClient().post(ApiConfig.refunds, {
      'ticket_id': ticketId,
      'reason': reason,
      'bank_name': bankName,
      'bank_account_number': bankAccountNumber,
      'bank_account_name': bankAccountName,
    });

    if (response['success'] == true) {
      return {
        'success': true,
        'message': response['message'] ?? 'Yêu cầu hoàn vé đã được gửi!',
        'data': response['data'],
      };
    }
    return {
      'success': false,
      'message': response['message'] ?? 'Không thể gửi yêu cầu hoàn vé',
    };
  }

  Future<List<RefundRequestModel>> getMyRefundRequests() async {
    final response = await ApiClient().get(ApiConfig.myRefunds);
    if (response['success'] == true && response['data'] != null) {
      final List list = response['data'] is List ? response['data'] : [];
      return list.map((e) => RefundRequestModel.fromJson(e)).toList();
    }
    return [];
  }
}
