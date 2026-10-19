import 'dart:convert';
import 'package:flutter/material.dart';
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
      city: json['city']?.toString() ?? json['province']?.toString(),
    );
  }

  String get summary {
    final parts = [name, addressLine, ward, district, city].where((e) => e != null && e.isNotEmpty).toList();
    return parts.isNotEmpty ? parts.join(', ') : 'TP. Hồ Chí Minh';
  }

  String get fullAddress {
    final parts = [addressLine, ward, district, city].where((e) => e != null && e.isNotEmpty).toList();
    return parts.isNotEmpty ? parts.join(', ') : '';
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
  final String? checkinStartTime;
  final String status;
  final String? checkInStatus;
  final String? attendeeName;
  final String? attendeeEmail;
  final String? attendeePhone;
  final String? orderCode;
  final double? price;
  final double? originalPrice;
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
    this.checkinStartTime,
    required this.status,
    this.checkInStatus,
    String? attendeeName,
    String? attendeeEmail,
    String? customerName,
    String? customerEmail,
    this.attendeePhone,
    this.orderCode,
    this.price,
    this.originalPrice,
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
    double? rawPrice;
    if (json['ticket_type'] is Map) {
      typeName = json['ticket_type']['name']?.toString();
      typeId = json['ticket_type']['id']?.toString();
      rawPrice = json['ticket_type']['price'] != null ? double.tryParse(json['ticket_type']['price'].toString()) : null;
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

    // Actual price vs unit price
    double? actualPrice = rawPrice;
    if (json['order_item'] is Map) {
      if (json['order_item']['actual_price'] != null) {
        actualPrice = double.tryParse(json['order_item']['actual_price'].toString());
      }
      if (json['order_item']['unit_price'] != null) {
        rawPrice = double.tryParse(json['order_item']['unit_price'].toString());
      }
    }
    actualPrice ??= json['price'] != null ? double.tryParse(json['price'].toString()) : 0.0;
    rawPrice ??= actualPrice;

    final code = json['ticket_code']?.toString() ?? json['code']?.toString() ?? 'TICK-0000';
    final qr = json['qr_code']?.toString() ?? code;

    // Order code
    String? orderCodeStr = json['order_code']?.toString();
    if (orderCodeStr == null && json['order'] is Map) {
      orderCodeStr = json['order']['order_code']?.toString();
    }

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
      checkinStartTime: sess?['checkin_start_time']?.toString() ?? json['checkin_start_time']?.toString(),
      status: json['status']?.toString().toUpperCase() ?? 'VALID',
      checkInStatus: json['check_in_status']?.toString().toUpperCase(),
      attendeeName: json['attendee_name']?.toString() ?? json['customer_name']?.toString() ?? json['buyer_name']?.toString() ?? 'Khách hàng',
      attendeeEmail: json['attendee_email']?.toString() ?? json['customer_email']?.toString() ?? json['buyer_email']?.toString(),
      attendeePhone: json['attendee_phone']?.toString() ?? json['customer_phone']?.toString(),
      orderCode: orderCodeStr,
      price: actualPrice,
      originalPrice: rawPrice,
      checkInTime: json['checked_in_at']?.toString() ?? json['check_in_time']?.toString(),
      venue: venueModel,
      refundPolicy: evt?['refund_policy'] is Map ? evt!['refund_policy'] : null,
    );
  }

  // Status checks aligning with backend
  bool get isUsed => status == 'USED' || checkInStatus == 'CHECKED_IN' || checkInTime != null;
  bool get isExpired => status == 'EXPIRED';
  bool get isRefundPending => status == 'REFUND_PENDING' || status == 'REFUND_REQUESTED';
  bool get isRefundRequested => isRefundPending;
  bool get isRefunded => status == 'REFUNDED';
  bool get isCancelled => status == 'CANCELLED';
  bool get isValid => (status == 'VALID' || status == 'AVAILABLE' || status == 'ACTIVE') && !isUsed && !isExpired && !isRefundPending && !isRefunded && !isCancelled;

  int get statusRank {
    if (isValid) return 1;
    if (isRefundPending) return 2;
    if (isUsed) return 3;
    if (isExpired) return 4;
    if (isCancelled) return 5;
    if (isRefunded) return 6;
    return 99;
  }

  String get formattedStatus {
    if (isRefundPending) return 'Chờ hoàn tiền';
    if (isRefunded) return 'Đã hoàn';
    if (isCancelled) return 'Đã hủy';
    if (isExpired) return 'Hết hạn';
    if (isUsed) return 'Đã dùng';
    return 'Hợp lệ';
  }

  Color get statusColor {
    if (isValid) return const Color(0xFF22C55E); // Emerald green
    if (isUsed) return const Color(0xFF06B6D4); // Cyan
    if (isRefundPending) return const Color(0xFFF59E0B); // Amber
    if (isRefunded) return const Color(0xFFA855F7); // Purple
    if (isExpired) return const Color(0xFFF43F5E); // Rose
    if (isCancelled) return const Color(0xFF94A3B8); // Slate
    return const Color(0xFF22C55E);
  }

  String get formattedPrice {
    if (price == null || price == 0) return 'Miễn phí';
    final formatter = NumberFormat.currency(locale: 'vi_VN', symbol: 'đ', decimalDigits: 0);
    return formatter.format(price);
  }

  String get formattedOriginalPrice {
    if (originalPrice == null || originalPrice == 0) return '';
    final formatter = NumberFormat.currency(locale: 'vi_VN', symbol: 'đ', decimalDigits: 0);
    return formatter.format(originalPrice);
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

  String get formattedCheckInTime {
    if (checkInTime == null) return '';
    try {
      final date = DateTime.parse(checkInTime!);
      return DateFormat('HH:mm • dd/MM/yyyy').format(date);
    } catch (_) {
      return checkInTime!;
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
