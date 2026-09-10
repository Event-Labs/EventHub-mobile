class EventCategoryModel {
  final String id;
  final String name;
  final String? icon;

  EventCategoryModel({
    required this.id,
    required this.name,
    this.icon,
  });

  factory EventCategoryModel.fromJson(Map<String, dynamic> json) {
    return EventCategoryModel(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? json['category_name']?.toString() ?? 'Tất cả',
      icon: json['icon']?.toString(),
    );
  }
}

class EventModel {
  final String id;
  final String title;
  final String? slug;
  final String? description;
  final String? coverImageUrl;
  final String? locationName;
  final String? address;
  final String? categoryName;
  final double? minPrice;
  final double? maxPrice;
  final String? startDate;
  final String? endDate;
  final String? organizerName;
  final bool isFeatured;
  final bool isLive;

  EventModel({
    required this.id,
    required this.title,
    this.slug,
    this.description,
    this.coverImageUrl,
    this.locationName,
    this.address,
    this.categoryName,
    this.minPrice,
    this.maxPrice,
    this.startDate,
    this.endDate,
    this.organizerName,
    this.isFeatured = false,
    this.isLive = false,
  });

  factory EventModel.fromJson(Map<String, dynamic> json) {
    return EventModel(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? 'Sự kiện EventHub',
      slug: json['slug']?.toString(),
      description: json['description']?.toString(),
      coverImageUrl: json['cover_image_url']?.toString() ?? json['banner_url']?.toString() ?? json['banner']?.toString(),
      locationName: json['location_name']?.toString() ?? json['venue_name']?.toString() ?? 'TP. Hồ Chí Minh',
      address: json['address']?.toString() ?? json['location']?.toString(),
      categoryName: json['category_name']?.toString() ?? json['category']?.toString() ?? 'ÂM NHẠC',
      minPrice: (json['min_price'] != null) ? double.tryParse(json['min_price'].toString()) : (json['price'] != null ? double.tryParse(json['price'].toString()) : 0.0),
      maxPrice: (json['max_price'] != null) ? double.tryParse(json['max_price'].toString()) : null,
      startDate: json['start_date']?.toString() ?? json['startDate']?.toString() ?? json['date']?.toString(),
      endDate: json['end_date']?.toString(),
      organizerName: json['organizer_name']?.toString() ?? json['organizer']?.toString() ?? 'EventHub Partner',
      isFeatured: json['is_featured'] == true || json['featured'] == true,
      isLive: json['status'] == 'ONGOING' || json['is_live'] == true,
    );
  }

  String get formattedPrice {
    if (minPrice == null || minPrice == 0) return 'Miễn phí';
    return '${minPrice!.toInt().toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]}.')} đ';
  }
}
