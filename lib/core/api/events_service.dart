import '../models/event_model.dart';
import 'api_client.dart';
import 'api_config.dart';

class EventsService {
  static final EventsService _instance = EventsService._internal();
  factory EventsService() => _instance;
  EventsService._internal();

  Future<List<EventCategoryModel>> getCategories() async {
    try {
      final response = await ApiClient().get(ApiConfig.categories);
      if (response['success'] == true && response['data'] != null) {
        final List list = response['data'] is List
            ? response['data']
            : (response['data']['items'] ?? []);
        final apiCats = <EventCategoryModel>[];
        for (final item in list) {
          try {
            if (item is Map) {
              apiCats.add(EventCategoryModel.fromJson(Map<String, dynamic>.from(item)));
            }
          } catch (_) {}
        }
        return [
          EventCategoryModel(id: 'all', name: 'Tất cả'),
          ...apiCats,
        ];
      }
    } catch (_) {}
    return [
      EventCategoryModel(id: 'all', name: 'Tất cả'),
    ];
  }

  Future<List<EventOrganizerModel>> getOrganizers() async {
    try {
      final response = await ApiClient().get(ApiConfig.organizers);
      if (response['success'] == true && response['data'] != null) {
        final List list = response['data'] is List
            ? response['data']
            : (response['data']['items'] ?? []);
        final orgs = <EventOrganizerModel>[];
        for (final item in list) {
          try {
            if (item is Map) {
              orgs.add(EventOrganizerModel.fromJson(Map<String, dynamic>.from(item)));
            }
          } catch (_) {}
        }
        return orgs;
      }
    } catch (_) {}
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

    try {
      final response = await ApiClient().get(ApiConfig.events, queryParams: queryParams);
      if (response['success'] == true && response['data'] != null) {
        final data = response['data'];
        final List list = data is List
            ? data
            : (data['items'] is List
                ? data['items']
                : (data['events'] is List ? data['events'] : []));
        final events = <EventModel>[];
        for (final item in list) {
          try {
            if (item is Map) {
              events.add(EventModel.fromJson(Map<String, dynamic>.from(item)));
            }
          } catch (_) {}
        }
        return events;
      }
    } catch (_) {}
    return [];
  }

  Future<EventModel> getEventDetail(String id) async {
    try {
      final response = await ApiClient().get('${ApiConfig.events}/$id');
      if (response['success'] == true && response['data'] != null) {
        return EventModel.fromJson(Map<String, dynamic>.from(response['data'] as Map));
      }
    } catch (_) {}
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
    try {
      final response = await ApiClient().get(ApiConfig.favoriteEvents);
      if (response['success'] == true && response['data'] != null) {
        final data = response['data'];
        final List list = data is List
            ? data
            : (data['items'] is List
                ? data['items']
                : (data['events'] is List ? data['events'] : []));
        final events = <EventModel>[];
        for (final item in list) {
          try {
            if (item is Map) {
              events.add(EventModel.fromJson(Map<String, dynamic>.from(item)));
            }
          } catch (_) {}
        }
        return events;
      }
    } catch (_) {}
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
