import '../models/event_model.dart';
import 'api_client.dart';
import 'api_config.dart';

class EventsService {
  static final EventsService _instance = EventsService._internal();
  factory EventsService() => _instance;
  EventsService._internal();

  Future<List<EventCategoryModel>> getCategories() async {
    final response = await ApiClient().get(ApiConfig.categories);
    if (response['success'] == true && response['data'] != null) {
      final List list = response['data'] is List
          ? response['data']
          : (response['data']['items'] ?? []);
      final apiCats = list.map((e) => EventCategoryModel.fromJson(e)).toList();
      return [
        EventCategoryModel(id: 'all', name: 'Tất cả'),
        ...apiCats,
      ];
    }
    return [
      EventCategoryModel(id: 'all', name: 'Tất cả'),
      EventCategoryModel(id: 'music', name: 'Âm nhạc'),
      EventCategoryModel(id: 'edm', name: 'EDM Fest'),
      EventCategoryModel(id: 'indie', name: 'Indie Nights'),
      EventCategoryModel(id: 'art', name: 'Nghệ thuật'),
    ];
  }

  Future<List<EventOrganizerModel>> getOrganizers() async {
    final response = await ApiClient().get(ApiConfig.organizers);
    if (response['success'] == true && response['data'] != null) {
      final List list = response['data'] is List
          ? response['data']
          : (response['data']['items'] ?? []);
      return list.map((e) => EventOrganizerModel.fromJson(e)).toList();
    }
    return [];
  }

  Future<List<EventModel>> getPublicEvents({String? search, String? categoryId}) async {
    final Map<String, String> queryParams = {};
    if (search != null && search.trim().isNotEmpty) {
      queryParams['keyword'] = search.trim();
    }
    if (categoryId != null && categoryId != 'all' && categoryId.trim().isNotEmpty) {
      queryParams['category_id'] = categoryId.trim();
    }
    queryParams['limit'] = '50';

    final response = await ApiClient().get(ApiConfig.events, queryParams: queryParams);
    if (response['success'] == true && response['data'] != null) {
      final data = response['data'];
      final List list = data is List
          ? data
          : (data['items'] is List
              ? data['items']
              : (data['events'] is List ? data['events'] : []));
      return list.map((e) => EventModel.fromJson(e)).toList();
    }

    // Mock fallback events if backend network not active
    return [
      EventModel(
        id: 'evt-1',
        title: 'Neon Horizon Festival 2025',
        categoryName: 'MUSIC FESTIVAL',
        minPrice: 450000,
        startTime: DateTime.now().add(const Duration(days: 3)).toIso8601String(),
        venue: EventVenueModel(
          name: 'SECC Exhibition Center',
          addressLine: '799 Nguyễn Văn Linh, Tân Phú',
          district: 'Quận 7',
          city: 'TP. Hồ Chí Minh',
        ),
        description: 'Trải nghiệm âm nhạc đa giác quan Neon Horizon 2025 với hệ thống âm thanh trình diễn đỉnh cao và sự góp mặt của hàng loạt nghệ sĩ tài năng thế giới.',
        coverImageUrl: 'https://images.unsplash.com/photo-1540039155733-5bb30b53aa14?auto=format&fit=crop&w=1200&q=80',
        bannerUrl: 'https://images.unsplash.com/photo-1540039155733-5bb30b53aa14?auto=format&fit=crop&w=1200&q=80',
        isFeatured: true,
      ),
      EventModel(
        id: 'evt-2',
        title: 'The Nocturnal Acoustic Echoes',
        categoryName: 'SAIGON INDIE NIGHTS',
        minPrice: 250000,
        startTime: DateTime.now().add(const Duration(days: 7)).toIso8601String(),
        venue: EventVenueModel(
          name: 'Hard Rock Cafe',
          addressLine: '39 Lê Duẩn',
          district: 'Quận 1',
          city: 'TP. Hồ Chí Minh',
        ),
        description: 'Đêm nhạc acoustic ấm cúng cùng những giai điệu mộc mạc làm say lòng người hâm mộ indie Sài Gòn.',
        coverImageUrl: 'https://images.unsplash.com/photo-1511671782779-c97d3d27a1d4?auto=format&fit=crop&w=1200&q=80',
        bannerUrl: 'https://images.unsplash.com/photo-1511671782779-c97d3d27a1d4?auto=format&fit=crop&w=1200&q=80',
        isLive: true,
      ),
      EventModel(
        id: 'evt-3',
        title: 'Sub-Zero Bass Fest: Phase 2',
        categoryName: 'GLOBAL BASS COLLECTIVE',
        minPrice: 380000,
        startTime: DateTime.now().add(const Duration(days: 12)).toIso8601String(),
        venue: EventVenueModel(
          name: 'The Warehouse 204',
          addressLine: 'Đường Song Hành',
          district: 'Thủ Đức',
          city: 'TP. Hồ Chí Minh',
        ),
        description: 'Âm thanh bass rung chuyển màn đêm, vũ đạo laser đỉnh cao đến từ các DJ hàng đầu.',
        coverImageUrl: 'https://images.unsplash.com/photo-1470225620780-dba8ba36b745?auto=format&fit=crop&w=1200&q=80',
        bannerUrl: 'https://images.unsplash.com/photo-1470225620780-dba8ba36b745?auto=format&fit=crop&w=1200&q=80',
      ),
    ];
  }

  Future<EventModel> getEventDetail(String id) async {
    final response = await ApiClient().get('${ApiConfig.events}/$id');
    if (response['success'] == true && response['data'] != null) {
      return EventModel.fromJson(response['data']);
    }
    final all = await getPublicEvents();
    if (all.any((e) => e.id == id)) {
      return all.firstWhere((e) => e.id == id);
    }
    if (all.isNotEmpty) {
      return all.first;
    }
    return EventModel(id: id, title: 'Chi tiết sự kiện');
  }

  Future<List<EventModel>> getFavoriteEvents() async {
    final response = await ApiClient().get(ApiConfig.favoriteEvents);
    if (response['success'] == true && response['data'] != null) {
      final data = response['data'];
      final List list = data is List
          ? data
          : (data['items'] is List
              ? data['items']
              : (data['events'] is List ? data['events'] : []));
      return list.map((e) => EventModel.fromJson(e)).toList();
    }
    return [];
  }

  Future<Map<String, dynamic>> toggleFavorite(String eventId) async {
    final response = await ApiClient().post(ApiConfig.toggleFavorite(eventId), {});
    if (response['success'] == true) {
      return {
        'success': true,
        'isFavorited': response['data']?['is_favorited'] ?? true,
        'message': response['message'] ?? 'Cập nhật yêu thích thành công',
      };
    }
    return {'success': false, 'message': response['message'] ?? 'Không thể lưu yêu thích'};
  }

  Future<Map<String, dynamic>> getSessionSeats(String sessionId) async {
    final response = await ApiClient().get('/events/sessions/$sessionId/seats');
    if (response['success'] == true && response['data'] != null) {
      return response['data'] as Map<String, dynamic>;
    }
    return {};
  }

  Future<Map<String, dynamic>> holdSeats(Map<String, dynamic> payload) async {
    final response = await ApiClient().post('/events/seats/hold', payload);
    return response;
  }
}
