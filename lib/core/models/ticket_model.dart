import 'dart:convert';
import 'package:intl/intl.dart';

class TicketVenueModel {
  final String? id;
  final String? name;
  final String? addressLine;
  final String? ward;
  final String? district;
  final String? city;

  TicketVenueModel({
    this.id,
    this.name,
    this.addressLine,
    this.ward,
    this.district,
    this.city,
  });

  factory TicketVenueModel.fromJson(Map<String, dynamic> json) {
    return TicketVenueModel(
      id: json['id']?.toString(),
      name: json['name']?.toString() ?? json['venue_name']?.toString(),
      addressLine: json['address_line']?.toString() ?? json['address']?.toString(),
      ward: json['ward']?.toString(),
      district: json['district']?.toString(),
      city: json['city']?.toString(),
    );
  }

  String get summary {
    final parts = [name, addressLine, ward, district, city].where((e) => e != null && e.isNotEmpty).toList();
    return parts.isNotEmpty ? parts.join(', ') : 'TP. Hồ Chí Minh';
  }
}

class TicketModel {
  final String ticketId;
  final String ticketCode;
  final String qrCode;
  final String eventId;
  final String eventName;
  final String? eventBanner;
  final String? ticketTypeId;
  final String? ticketType;
  final String? seatName;
  final String? sessionId;
  final String? sessionName;
  final String? sessionTime;
  final String? sessionEndTime;
  final String status;
  final String? checkInStatus;
  final String? attendeeName;
  final String? attendeeEmail;
  final double? price;
  final String? checkInTime;
  final TicketVenueModel? venue;
  final Map<String, dynamic>? refundPolicy;

  TicketModel({
    required this.ticketId,
    required this.ticketCode,
    this.qrCode = '',
    this.eventId = '',
    required this.eventName,
    this.eventBanner,
    this.ticketTypeId,
    this.ticketType,
    this.seatName,
    this.sessionId,
    this.sessionName,
    this.sessionTime,
    this.sessionEndTime,
    required this.status,
    this.checkInStatus,
    String? attendeeName,
    String? attendeeEmail,
    String? customerName,
    String? customerEmail,
    this.price,
    this.checkInTime,
    this.venue,
    this.refundPolicy,
  })  : attendeeName = attendeeName ?? customerName,
        attendeeEmail = attendeeEmail ?? customerEmail;

  String? get customerName => attendeeName;
  String? get customerEmail => attendeeEmail;

  factory TicketModel.fromJson(Map<String, dynamic> json) {
    // Nested event
    Map<String, dynamic>? evt;
    if (json['event'] is Map) {
      evt = json['event'];
    }

    // Nested session
    Map<String, dynamic>? sess;
    if (json['session'] is Map) {
      sess = json['session'];
    }

    // Nested venue
    TicketVenueModel? venueModel;
    if (json['venue'] is Map) {
      venueModel = TicketVenueModel.fromJson(json['venue']);
    } else if (json['venue_name'] != null || json['venue_address'] != null) {
      venueModel = TicketVenueModel.fromJson(json);
    }

    // Nested ticket_type
    String? typeName;
    String? typeId;
    double? ticketPrice;
    if (json['ticket_type'] is Map) {
      typeName = json['ticket_type']['name']?.toString();
      typeId = json['ticket_type']['id']?.toString();
      ticketPrice = json['ticket_type']['price'] != null ? double.tryParse(json['ticket_type']['price'].toString()) : null;
    }

    // Seat label
    String? seatLabel;
    if (json['seat'] is Map) {
      seatLabel = json['seat']['label']?.toString();
    } else if (json['row_label'] != null || json['seat_number'] != null) {
      seatLabel = '${json['row_label'] ?? ''}${json['seat_number'] ?? ''}'.trim();
    }
    if (seatLabel == null || seatLabel.isEmpty) {
      seatLabel = json['seat_name']?.toString() ?? 'Khu vực tự do (GA)';
    }

    // Actual price
    if (json['order_item'] is Map && json['order_item']['actual_price'] != null) {
      ticketPrice = double.tryParse(json['order_item']['actual_price'].toString());
    }
    ticketPrice ??= json['price'] != null ? double.tryParse(json['price'].toString()) : 0.0;

    final code = json['ticket_code']?.toString() ?? json['code']?.toString() ?? 'TICK-0000';
    final qr = json['qr_code']?.toString() ?? code;

    return TicketModel(
      ticketId: json['id']?.toString() ?? json['ticketId']?.toString() ?? '',
      ticketCode: code,
      qrCode: qr,
      eventId: evt?['id']?.toString() ?? json['event_id']?.toString() ?? '',
      eventName: evt?['title']?.toString() ?? json['event_title']?.toString() ?? json['eventName']?.toString() ?? 'Sự kiện EventHub',
      eventBanner: evt?['banner_url']?.toString() ?? evt?['thumbnail_url']?.toString() ?? json['cover_image_url']?.toString() ?? json['banner_url']?.toString(),
      ticketTypeId: typeId ?? json['ticket_type_id']?.toString(),
      ticketType: typeName ?? json['ticket_type_name']?.toString() ?? json['ticketType']?.toString() ?? 'Vé tham dự',
      seatName: seatLabel,
      sessionId: sess?['id']?.toString() ?? json['event_session_id']?.toString(),
      sessionName: sess?['name']?.toString() ?? json['session_name']?.toString(),
      sessionTime: sess?['start_time']?.toString() ?? json['session_start_time']?.toString() ?? json['sessionTime']?.toString(),
      sessionEndTime: sess?['end_time']?.toString() ?? json['session_end_time']?.toString(),
      status: json['status']?.toString().toUpperCase() ?? 'VALID',
      checkInStatus: json['check_in_status']?.toString().toUpperCase(),
      attendeeName: json['attendee_name']?.toString() ?? json['customer_name']?.toString() ?? json['buyer_name']?.toString() ?? 'Khách hàng',
      attendeeEmail: json['attendee_email']?.toString() ?? json['customer_email']?.toString() ?? json['buyer_email']?.toString(),
      price: ticketPrice,
      checkInTime: json['checked_in_at']?.toString() ?? json['check_in_time']?.toString(),
      venue: venueModel,
      refundPolicy: evt?['refund_policy'] is Map ? evt!['refund_policy'] : null,
    );
  }

  bool get isUsed => status == 'USED' || checkInStatus == 'CHECKED_IN' || checkInTime != null;
  bool get isExpired => status == 'EXPIRED';
  bool get isRefundRequested => status == 'REFUND_REQUESTED';
  bool get isRefunded => status == 'REFUNDED';
  bool get isCancelled => status == 'CANCELLED';
  bool get isValid => (status == 'AVAILABLE' || status == 'VALID' || status == 'ACTIVE') && !isUsed && !isExpired && !isRefundRequested && !isRefunded && !isCancelled;

  String get formattedStatus {
    if (isRefundRequested) return 'Đang chờ hoàn';
    if (isRefunded) return 'Đã hoàn vé';
    if (isCancelled) return 'Đã hủy';
    if (isExpired) return 'Hết hạn';
    if (isUsed) return 'Đã check-in';
    return 'Hợp lệ';
  }

  String get formattedPrice {
    if (price == null || price == 0) return 'Miễn phí';
    final formatter = NumberFormat.currency(locale: 'vi_VN', symbol: 'đ', decimalDigits: 0);
    return formatter.format(price);
  }

  String get formattedSessionTime {
    if (sessionTime == null) return 'Sắp diễn ra';
    try {
      final date = DateTime.parse(sessionTime!);
      return DateFormat('HH:mm • dd/MM/yyyy').format(date);
    } catch (_) {
      return sessionTime!;
    }
  }

  String get qrPayload {
    return jsonEncode({
      'type': 'EVENTHUB_TICKET',
      'ticket_id': ticketId,
      'ticket_code': ticketCode,
      'qr_code': qrCode,
      'event_id': eventId,
      'session_id': sessionId,
    });
  }
}
