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
  final String? rawAttendeeName;
  final String? rawAttendeeEmail;
  final String? buyerName;
  final String? buyerEmail;
  final String? buyerPhone;
  final String? orderCode;
  final double? price;
  final double? originalPrice;
  final String? checkInTime;
  final String? checkinMethod;
  final String? checkedInByName;
  final String? checkedInByEmail;
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
    this.rawAttendeeName,
    this.rawAttendeeEmail,
    this.buyerName,
    this.buyerEmail,
    this.buyerPhone,
    this.orderCode,
    this.price,
    this.originalPrice,
    this.checkInTime,
    this.checkinMethod,
    this.checkedInByName,
    this.checkedInByEmail,
    this.venue,
    this.refundPolicy,
  })  : attendeeName = attendeeName ?? customerName,
        attendeeEmail = attendeeEmail ?? customerEmail;

  String? get customerName => attendeeName;
  String? get customerEmail => attendeeEmail;

  /// Whether ticket attendee differs from order buyer (matches Web normalizeTicket)
  bool get isDifferentAttendee {
    final raw = rawAttendeeName?.trim().toLowerCase() ?? '';
    final buyer = buyerName?.trim().toLowerCase() ?? '';
    return raw.isNotEmpty && buyer.isNotEmpty && raw != buyer;
  }

  String get displayPrimaryName {
    final a = attendeeName?.trim() ?? '';
    if (a.isNotEmpty && a != 'Khách hàng') return a;
    final b = buyerName?.trim() ?? '';
    if (b.isNotEmpty) return b;
    return a.isNotEmpty ? a : 'Khách hàng';
  }

  static String? _nonEmptyString(dynamic value) {
    if (value == null) return null;
    final str = value.toString().trim();
    return str.isEmpty ? null : str;
  }

  factory TicketModel.fromJson(Map<String, dynamic> json) {
    // Nested event
    Map<String, dynamic>? evt;
    if (json['event'] is Map) {
      evt = Map<String, dynamic>.from(json['event'] as Map);
    }

    // Nested session
    Map<String, dynamic>? sess;
    if (json['session'] is Map) {
      sess = Map<String, dynamic>.from(json['session'] as Map);
    }

    final Map<String, dynamic>? buyer =
        json['buyer'] is Map ? Map<String, dynamic>.from(json['buyer'] as Map) : null;
    final Map<String, dynamic>? order =
        json['order'] is Map ? Map<String, dynamic>.from(json['order'] as Map) : null;
    final Map<String, dynamic>? checkedInBy =
        json['checked_in_by'] is Map ? Map<String, dynamic>.from(json['checked_in_by'] as Map) : null;

    // Nested venue
    TicketVenueModel? venueModel;
    if (json['venue'] is Map) {
      venueModel = TicketVenueModel.fromJson(Map<String, dynamic>.from(json['venue'] as Map));
    } else if (json['venue_name'] != null || json['venue_address'] != null) {
      venueModel = TicketVenueModel.fromJson(json);
    }

    // Nested ticket_type
    String? typeName;
    String? typeId;
    double? rawPrice;
    if (json['ticket_type'] is Map) {
      typeName = _nonEmptyString(json['ticket_type']['name']);
      typeId = _nonEmptyString(json['ticket_type']['id']);
      rawPrice = json['ticket_type']['price'] != null ? double.tryParse(json['ticket_type']['price'].toString()) : null;
    }

    // Seat label
    String? seatLabel;
    if (json['seat'] is Map) {
      seatLabel = _nonEmptyString(json['seat']['label']) ??
          _nonEmptyString('${json['seat']['row_label'] ?? ''}${json['seat']['seat_number'] ?? ''}');
    } else if (json['row_label'] != null || json['seat_number'] != null) {
      seatLabel = _nonEmptyString('${json['row_label'] ?? ''}${json['seat_number'] ?? ''}');
    }
    seatLabel ??= _nonEmptyString(json['seat_name']) ?? 'Khu vực tự do (GA)';

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

    final code = _nonEmptyString(json['ticket_code']) ??
        _nonEmptyString(json['ticketCode']) ??
        _nonEmptyString(json['code']) ??
        'TICK-0000';
    final qr = _nonEmptyString(json['qr_code']) ?? _nonEmptyString(json['qrCode']) ?? code;

    // Order code
    final orderCodeStr = _nonEmptyString(json['order_code']) ?? _nonEmptyString(order?['order_code']);

    final rawAttName = _nonEmptyString(json['raw_attendee_name']);
    final rawAttEmail = _nonEmptyString(json['raw_attendee_email']);
    final bName = _nonEmptyString(json['buyer_name']) ??
        _nonEmptyString(buyer?['name']) ??
        _nonEmptyString(order?['buyer_name']) ??
        _nonEmptyString(json['buyerName']);
    final bEmail = _nonEmptyString(json['buyer_email']) ??
        _nonEmptyString(buyer?['email']) ??
        _nonEmptyString(order?['buyer_email']) ??
        _nonEmptyString(json['buyerEmail']);
    final bPhone = _nonEmptyString(json['buyer_phone']) ??
        _nonEmptyString(buyer?['phone']) ??
        _nonEmptyString(order?['buyer_phone']) ??
        _nonEmptyString(json['buyerPhone']);

    final effAttName = rawAttName ??
        _nonEmptyString(json['attendee_name']) ??
        _nonEmptyString(json['attendeeName']) ??
        _nonEmptyString(json['customer_name']) ??
        bName ??
        'Khách hàng';
    final effAttEmail = rawAttEmail ??
        _nonEmptyString(json['attendee_email']) ??
        _nonEmptyString(json['attendeeEmail']) ??
        _nonEmptyString(json['customer_email']) ??
        bEmail;
    final effPhone = _nonEmptyString(json['attendee_phone']) ??
        _nonEmptyString(json['customer_phone']) ??
        bPhone;

    return TicketModel(
      ticketId: _nonEmptyString(json['id']) ?? _nonEmptyString(json['ticketId']) ?? _nonEmptyString(json['ticket_id']) ?? '',
      ticketCode: code,
      qrCode: qr,
      eventId: _nonEmptyString(evt?['id']) ?? _nonEmptyString(json['event_id']) ?? '',
      eventName: _nonEmptyString(evt?['title']) ??
          _nonEmptyString(json['event_title']) ??
          _nonEmptyString(json['eventName']) ??
          'Sự kiện EventHub',
      eventBanner: _nonEmptyString(evt?['banner_url']) ??
          _nonEmptyString(evt?['thumbnail_url']) ??
          _nonEmptyString(json['cover_image_url']) ??
          _nonEmptyString(json['banner_url']),
      ticketTypeId: typeId ?? _nonEmptyString(json['ticket_type_id']),
      ticketType: typeName ??
          _nonEmptyString(json['ticket_type_name']) ??
          _nonEmptyString(json['ticketType']) ??
          'Vé tham dự',
      seatName: seatLabel,
      sessionId: _nonEmptyString(sess?['id']) ?? _nonEmptyString(json['event_session_id']),
      sessionName: _nonEmptyString(sess?['name']) ?? _nonEmptyString(sess?['session_name']) ?? _nonEmptyString(json['session_name']),
      sessionTime: _nonEmptyString(sess?['start_time']) ?? _nonEmptyString(json['session_start_time']) ?? _nonEmptyString(json['sessionTime']),
      sessionEndTime: _nonEmptyString(sess?['end_time']) ?? _nonEmptyString(json['session_end_time']),
      checkinStartTime: _nonEmptyString(sess?['checkin_start_time']) ?? _nonEmptyString(json['checkin_start_time']),
      status: _nonEmptyString(json['status'])?.toUpperCase() ?? 'VALID',
      checkInStatus: _nonEmptyString(json['check_in_status'])?.toUpperCase(),
      attendeeName: effAttName,
      attendeeEmail: effAttEmail,
      attendeePhone: effPhone,
      rawAttendeeName: rawAttName ?? _nonEmptyString(json['attendee_name']),
      rawAttendeeEmail: rawAttEmail ?? _nonEmptyString(json['attendee_email']),
      buyerName: bName,
      buyerEmail: bEmail,
      buyerPhone: bPhone,
      orderCode: orderCodeStr,
      price: actualPrice,
      originalPrice: rawPrice,
      checkInTime: _nonEmptyString(json['checked_in_at']) ?? _nonEmptyString(json['check_in_time']),
      checkinMethod: _nonEmptyString(json['checkin_method']),
      checkedInByName: _nonEmptyString(checkedInBy?['name']) ?? _nonEmptyString(checkedInBy?['full_name']) ?? _nonEmptyString(json['checked_in_by_name']),
      checkedInByEmail: _nonEmptyString(checkedInBy?['email']) ?? _nonEmptyString(json['checked_in_by_email']),
      venue: venueModel,
      refundPolicy: evt?['refund_policy'] is Map ? evt!['refund_policy'] : null,
    );
  }

  // Status checks aligning with backend
  bool get isUsed => status == 'USED' || checkInStatus == 'CHECKED_IN' || (checkInTime != null && checkInTime!.trim().isNotEmpty);
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

  /// Compact QR payload matching Web (TicketDetailPage / StaffDirectBookingPage / tickets.service.js)
  static String buildQrPayload({
    required String ticketCode,
    String? qrCode,
    String? ticketId,
  }) {
    final ref = ticketCode.trim().isNotEmpty
        ? ticketCode.trim()
        : ((qrCode ?? '').trim().isNotEmpty ? qrCode!.trim() : (ticketId ?? '').trim());
    return jsonEncode({
      'type': 'EVENTHUB_TICKET',
      'ticket_code': ref,
    });
  }

  String get qrPayload => buildQrPayload(
        ticketCode: ticketCode,
        qrCode: qrCode,
        ticketId: ticketId,
      );

  TicketModel copyWith({
    String? status,
    String? checkInStatus,
    String? checkInTime,
    String? checkinMethod,
    String? checkedInByName,
    String? checkedInByEmail,
    String? attendeeName,
    String? attendeeEmail,
    String? attendeePhone,
    String? seatName,
  }) {
    return TicketModel(
      ticketId: ticketId,
      ticketCode: ticketCode,
      qrCode: qrCode,
      eventId: eventId,
      eventName: eventName,
      eventBanner: eventBanner,
      ticketTypeId: ticketTypeId,
      ticketType: ticketType,
      seatName: seatName ?? this.seatName,
      sessionId: sessionId,
      sessionName: sessionName,
      sessionTime: sessionTime,
      sessionEndTime: sessionEndTime,
      checkinStartTime: checkinStartTime,
      status: status ?? this.status,
      checkInStatus: checkInStatus ?? this.checkInStatus,
      attendeeName: attendeeName ?? this.attendeeName,
      attendeeEmail: attendeeEmail ?? this.attendeeEmail,
      attendeePhone: attendeePhone ?? this.attendeePhone,
      rawAttendeeName: rawAttendeeName,
      rawAttendeeEmail: rawAttendeeEmail,
      buyerName: buyerName,
      buyerEmail: buyerEmail,
      buyerPhone: buyerPhone,
      orderCode: orderCode,
      price: price,
      originalPrice: originalPrice,
      checkInTime: checkInTime ?? this.checkInTime,
      checkinMethod: checkinMethod ?? this.checkinMethod,
      checkedInByName: checkedInByName ?? this.checkedInByName,
      checkedInByEmail: checkedInByEmail ?? this.checkedInByEmail,
      venue: venue,
      refundPolicy: refundPolicy,
    );
  }
}
