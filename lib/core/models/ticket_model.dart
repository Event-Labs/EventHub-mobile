class TicketModel {
  final String ticketId;
  final String ticketCode;
  final String eventName;
  final String? eventBanner;
  final String? ticketType;
  final String? seatName;
  final String? sessionTime;
  final String status;
  final String? customerName;
  final String? customerEmail;
  final double? price;
  final String? checkInTime;

  TicketModel({
    required this.ticketId,
    required this.ticketCode,
    required this.eventName,
    this.eventBanner,
    this.ticketType,
    this.seatName,
    this.sessionTime,
    required this.status,
    this.customerName,
    this.customerEmail,
    this.price,
    this.checkInTime,
  });

  factory TicketModel.fromJson(Map<String, dynamic> json) {
    return TicketModel(
      ticketId: json['id']?.toString() ?? json['ticketId']?.toString() ?? '',
      ticketCode: json['ticket_code']?.toString() ?? json['code']?.toString() ?? 'TICK-UNKN-00',
      eventName: json['event_title']?.toString() ?? json['eventName']?.toString() ?? 'Neon Horizon Festival 2025',
      eventBanner: json['cover_image_url']?.toString() ?? json['banner_url']?.toString(),
      ticketType: json['ticket_type_name']?.toString() ?? json['ticketType']?.toString() ?? 'Standard Access',
      seatName: json['seat_name']?.toString() ?? json['seat']?.toString() ?? 'GA - Free Standing',
      sessionTime: json['session_start_time']?.toString() ?? json['sessionTime']?.toString() ?? '20:00 - 23:30',
      status: json['status']?.toString().toUpperCase() ?? 'AVAILABLE',
      customerName: json['customer_name']?.toString() ?? json['full_name']?.toString() ?? 'Khách hàng',
      customerEmail: json['customer_email']?.toString() ?? json['email']?.toString(),
      price: json['price'] != null ? double.tryParse(json['price'].toString()) : 0.0,
      checkInTime: json['check_in_time']?.toString() ?? json['checkedInAt']?.toString(),
    );
  }

  bool get isUsed => status == 'USED' || status == 'CHECKED_IN';
  bool get isValid => status == 'AVAILABLE' || status == 'VALID' || status == 'ACTIVE';

  String get formattedStatus {
    if (isUsed) return 'ĐÃ KHÁCH CHECK-IN';
    if (isValid) return 'VÉ HỢP LỆ';
    return 'VÉ ĐÃ HỦY / HẾT HẠN';
  }
}
