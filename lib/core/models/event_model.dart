import 'package:intl/intl.dart';

class EventCategoryModel {
  final String id;
  final String name;
  final String? icon;
  final String? slug;

  EventCategoryModel({
    required this.id,
    required this.name,
    this.icon,
    this.slug,
  });

  factory EventCategoryModel.fromJson(Map<String, dynamic> json) {
    return EventCategoryModel(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? json['category_name']?.toString() ?? 'Tất cả',
      icon: json['icon']?.toString(),
      slug: json['slug']?.toString(),
    );
  }
}

class EventVenueModel {
  final String? id;
  final String? name;
  final String? city;
  final String? district;
  final String? addressLine;
  final String? summary;
  final double? latitude;
  final double? longitude;

  EventVenueModel({
    this.id,
    this.name,
    this.city,
    this.district,
    this.addressLine,
    this.summary,
    this.latitude,
    this.longitude,
  });

  factory EventVenueModel.fromJson(Map<String, dynamic> json) {
    final name = json['name']?.toString() ?? json['venue_name']?.toString();
    final addressLine = json['address_line']?.toString() ?? json['address']?.toString();
    final district = json['district']?.toString();
    final city = json['city']?.toString();

    final parts = [name, addressLine, district, city].where((e) => e != null && e.isNotEmpty).toList();
    final defaultSummary = parts.join(', ');

    return EventVenueModel(
      id: json['id']?.toString(),
      name: name,
      city: city,
      district: district,
      addressLine: addressLine,
      summary: json['summary']?.toString() ?? (defaultSummary.isNotEmpty ? defaultSummary : 'TP. Hồ Chí Minh'),
      latitude: json['latitude'] != null ? double.tryParse(json['latitude'].toString()) : null,
      longitude: json['longitude'] != null ? double.tryParse(json['longitude'].toString()) : null,
    );
  }
}

class EventOrganizerModel {
  final String? id;
  final String? fullName;
  final String? organizationName;
  final String? avatarUrl;
  final String? email;
  final String? phone;

  EventOrganizerModel({
    this.id,
    this.fullName,
    this.organizationName,
    this.avatarUrl,
    this.email,
    this.phone,
  });

  factory EventOrganizerModel.fromJson(Map<String, dynamic> json) {
    return EventOrganizerModel(
      id: json['id']?.toString(),
      fullName: json['full_name']?.toString() ?? json['name']?.toString(),
      organizationName: json['organization_name']?.toString() ?? json['organization']?.toString(),
      avatarUrl: json['avatar_url']?.toString() ?? json['avatar']?.toString(),
      email: json['email']?.toString(),
      phone: json['phone']?.toString(),
    );
  }

  String get displayName => organizationName?.isNotEmpty == true
      ? organizationName!
      : (fullName?.isNotEmpty == true ? fullName! : 'Ban tổ chức EventHub');
}

class TicketTypeModel {
  final String id;
  final String name;
  final String? description;
  final double price;
  final int quantity;
  final int soldQuantity;
  final int availableQuantity;
  final String? saleStart;
  final String? saleEnd;
  final String? sessionId;

  TicketTypeModel({
    required this.id,
    required this.name,
    this.description,
    required this.price,
    this.quantity = 0,
    this.soldQuantity = 0,
    this.availableQuantity = 0,
    this.saleStart,
    this.saleEnd,
    this.sessionId,
  });

  factory TicketTypeModel.fromJson(Map<String, dynamic> json) {
    return TicketTypeModel(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? json['title']?.toString() ?? 'Vé tham dự',
      description: json['description']?.toString(),
      price: json['price'] != null ? double.tryParse(json['price'].toString()) ?? 0.0 : 0.0,
      quantity: json['quantity'] != null ? int.tryParse(json['quantity'].toString()) ?? 0 : 0,
      soldQuantity: json['sold_quantity'] != null ? int.tryParse(json['sold_quantity'].toString()) ?? 0 : 0,
      availableQuantity: json['available_quantity'] != null
          ? int.tryParse(json['available_quantity'].toString()) ?? 0
          : (json['quantity'] != null ? int.tryParse(json['quantity'].toString()) ?? 0 : 0),
      saleStart: json['sale_start']?.toString(),
      saleEnd: json['sale_end']?.toString(),
      sessionId: json['session_id']?.toString(),
    );
  }

  bool get isSoldOut => availableQuantity <= 0;

  String get formattedPrice {
    if (price == 0) return 'Miễn phí';
    final formatter = NumberFormat.currency(locale: 'vi_VN', symbol: 'đ', decimalDigits: 0);
    return formatter.format(price);
  }
}

class EventSessionModel {
  final String id;
  final String? name;
  final String? startTime;
  final String? endTime;
  final EventVenueModel? venue;
  final List<TicketTypeModel> ticketTypes;

  EventSessionModel({
    required this.id,
    this.name,
    this.startTime,
    this.endTime,
    this.venue,
    this.ticketTypes = const [],
  });

  factory EventSessionModel.fromJson(Map<String, dynamic> json) {
    return EventSessionModel(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? json['title']?.toString(),
      startTime: json['start_time']?.toString() ?? json['startDate']?.toString(),
      endTime: json['end_time']?.toString() ?? json['endDate']?.toString(),
      venue: json['venue'] != null ? EventVenueModel.fromJson(json['venue']) : null,
      ticketTypes: json['ticket_types'] is List
          ? (json['ticket_types'] as List).map((t) => TicketTypeModel.fromJson(t)).toList()
          : [],
    );
  }

  String get formattedTime {
    if (startTime == null) return 'Sắp diễn ra';
    try {
      final date = DateTime.parse(startTime!);
      return DateFormat('HH:mm - dd/MM/yyyy').format(date);
    } catch (_) {
      return startTime!;
    }
  }
}

class EventModel {
  final String id;
  final String title;
  final String? slug;
  final String? shortDescription;
  final String? description;
  final String? coverImageUrl;
  final String? bannerUrl;
  final String? categoryName;
  final String? categoryId;
  final double? minPrice;
  final double? maxPrice;
  final String? startTime;
  final String? endTime;
  final EventVenueModel? venue;
  final EventOrganizerModel? organizer;
  final List<EventSessionModel> sessions;
  final List<TicketTypeModel> ticketTypes;
  final bool isFavorited;
  final bool isFeatured;
  final bool isLive;
  final String? refundPolicy;
  final String? additionalTerms;

  EventModel({
    required this.id,
    required this.title,
    this.slug,
    this.shortDescription,
    this.description,
    this.coverImageUrl,
    this.bannerUrl,
    this.categoryName,
    this.categoryId,
    this.minPrice,
    this.maxPrice,
    this.startTime,
    this.endTime,
    this.venue,
    this.organizer,
    this.sessions = const [],
    this.ticketTypes = const [],
    this.isFavorited = false,
    this.isFeatured = false,
    this.isLive = false,
    this.refundPolicy,
    this.additionalTerms,
  });

  factory EventModel.fromJson(Map<String, dynamic> json) {
    // Extract Category
    String? catName;
    String? catId;
    if (json['category'] is Map) {
      catName = json['category']['name']?.toString();
      catId = json['category']['id']?.toString();
    } else {
      catName = json['category_name']?.toString() ?? json['category']?.toString();
      catId = json['category_id']?.toString();
    }

    // Extract Venue
    EventVenueModel? venueModel;
    if (json['venue'] is Map) {
      venueModel = EventVenueModel.fromJson(json['venue']);
    } else if (json['location_name'] != null || json['venue_name'] != null || json['address'] != null) {
      venueModel = EventVenueModel.fromJson(json);
    }

    // Extract Organizer
    EventOrganizerModel? organizerModel;
    if (json['organizer'] is Map) {
      organizerModel = EventOrganizerModel.fromJson(json['organizer']);
    } else if (json['organizer_name'] != null) {
      organizerModel = EventOrganizerModel(fullName: json['organizer_name']?.toString());
    }

    // Extract Sessions
    List<EventSessionModel> sessionsList = [];
    if (json['sessions'] is List) {
      sessionsList = (json['sessions'] as List).map((s) => EventSessionModel.fromJson(s)).toList();
    }

    // Extract Ticket Types
    List<TicketTypeModel> ticketTypesList = [];
    if (json['ticket_types'] is List) {
      ticketTypesList = (json['ticket_types'] as List).map((t) => TicketTypeModel.fromJson(t)).toList();
    }

    // Min and Max prices
    double? minP;
    double? maxP;
    if (json['price_range'] is Map) {
      minP = json['price_range']['min'] != null ? double.tryParse(json['price_range']['min'].toString()) : null;
      maxP = json['price_range']['max'] != null ? double.tryParse(json['price_range']['max'].toString()) : null;
    }
    minP ??= json['min_price'] != null ? double.tryParse(json['min_price'].toString()) : (json['price'] != null ? double.tryParse(json['price'].toString()) : null);
    maxP ??= json['max_price'] != null ? double.tryParse(json['max_price'].toString()) : null;

    final imgUrl = json['banner_url']?.toString() ??
        json['cover_image_url']?.toString() ??
        json['thumbnail_url']?.toString() ??
        json['image']?.toString();

    final sTime = json['start_time']?.toString() ?? json['start_date']?.toString() ?? json['startDate']?.toString();
    final eTime = json['end_time']?.toString() ?? json['end_date']?.toString() ?? json['endDate']?.toString();

    return EventModel(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? 'Sự kiện EventHub',
      slug: json['slug']?.toString(),
      shortDescription: json['short_description']?.toString(),
      description: json['description']?.toString() ?? json['short_description']?.toString(),
      coverImageUrl: imgUrl,
      bannerUrl: imgUrl,
      categoryName: catName ?? 'Âm nhạc',
      categoryId: catId,
      minPrice: minP,
      maxPrice: maxP,
      startTime: sTime,
      endTime: eTime,
      venue: venueModel,
      organizer: organizerModel,
      sessions: sessionsList,
      ticketTypes: ticketTypesList,
      isFavorited: json['is_favorited'] == true,
      isFeatured: json['is_featured'] == true || json['featured'] == true,
      isLive: json['status'] == 'ONGOING' || json['is_live'] == true,
      refundPolicy: json['refund_policy']?.toString(),
      additionalTerms: json['additional_terms']?.toString(),
    );
  }

  EventModel copyWith({
    bool? isFavorited,
  }) {
    return EventModel(
      id: id,
      title: title,
      slug: slug,
      shortDescription: shortDescription,
      description: description,
      coverImageUrl: coverImageUrl,
      bannerUrl: bannerUrl,
      categoryName: categoryName,
      categoryId: categoryId,
      minPrice: minPrice,
      maxPrice: maxPrice,
      startTime: startTime,
      endTime: endTime,
      venue: venue,
      organizer: organizer,
      sessions: sessions,
      ticketTypes: ticketTypes,
      isFavorited: isFavorited ?? this.isFavorited,
      isFeatured: isFeatured,
      isLive: isLive,
      refundPolicy: refundPolicy,
      additionalTerms: additionalTerms,
    );
  }

  String get formattedPrice {
    final formatter = NumberFormat.currency(locale: 'vi_VN', symbol: 'đ', decimalDigits: 0);
    if (minPrice == null || (minPrice == 0 && (maxPrice == null || maxPrice == 0))) {
      return 'Miễn phí';
    }
    if (maxPrice != null && maxPrice != minPrice && maxPrice! > 0) {
      return '${formatter.format(minPrice)} - ${formatter.format(maxPrice)}';
    }
    return formatter.format(minPrice ?? 0);
  }

  String get formattedDateTime {
    if (startTime == null) return 'Sắp cập nhật';
    try {
      final date = DateTime.parse(startTime!);
      return DateFormat('dd/MM/yyyy • HH:mm').format(date);
    } catch (_) {
      return startTime!;
    }
  }

  String get locationSummary => venue?.summary ?? 'TP. Hồ Chí Minh';
  String get organizerDisplayName => organizer?.displayName ?? 'Ban tổ chức EventHub';
}
