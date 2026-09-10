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
      final List list = response['data'];
      return list.map((e) => EventCategoryModel.fromJson(e)).toList();
    }
    return [
      EventCategoryModel(id: 'all', name: 'Tất cả'),
      EventCategoryModel(id: 'music', name: 'Âm nhạc'),
      EventCategoryModel(id: 'edm', name: 'EDM Fest'),
      EventCategoryModel(id: 'indie', name: 'Indie Nights'),
      EventCategoryModel(id: 'art', name: 'Nghệ thuật'),
    ];
  }

  Future<List<EventModel>> getPublicEvents({String? search, String? categoryId}) async {
    final Map<String, String> queryParams = {};
    if (search != null && search.isNotEmpty) {
      queryParams['search'] = search;
    }
    if (categoryId != null && categoryId != 'all' && categoryId.isNotEmpty) {
      queryParams['categoryId'] = categoryId;
    }

    final response = await ApiClient().get(ApiConfig.events, queryParams: queryParams);
    if (response['success'] == true && response['data'] != null) {
      final List list = response['data'] is List ? response['data'] : (response['data']['events'] ?? []);
      return list.map((e) => EventModel.fromJson(e)).toList();
    }

    // Mock fallback events if backend network not active
    return [
      EventModel(
        id: 'evt-1',
        title: 'Neon Horizon Festival 2025',
        categoryName: 'MUSIC FESTIVAL',
        minPrice: 450000,
        startDate: 'Friday, Dec 28, 2025 • 18:00',
        locationName: 'SECC Exhibition Center, Quận 7',
        description: 'Trải nghiệm âm nhạc đa giác quan Neon Horizon 2025 với hệ thống âm thanh trình diễn đỉnh cao.',
        coverImageUrl: 'https://lh3.googleusercontent.com/aida-public/AB6AXuCsh1MyeOrExv0OTGWPXymZBnHdDiqnLogqJTML1O6osQPpeQP11Xa069TLuCwM-qYBI6xOmazp-7pg5MCxPM4TcaDHr7rhFP7PRyR7QS79TjINZdZ4k4DfgPm1umU1TYFb7w-_8bpoVl9R1VTWzNVop69NIQAPIhcnx8LZ1FDgsJ4ME58mNas6uSxXTAiSOwUKbbgiKBdEG1KIhXlEOKa-7pEzLNe1z7_DJbEJhZKSIizd6czYP7-3',
        isFeatured: true,
      ),
      EventModel(
        id: 'evt-2',
        title: 'The Nocturnal Acoustic Echoes',
        categoryName: 'SAIGON INDIE NIGHTS',
        minPrice: 250000,
        startDate: 'Fri, Jan 03 • 20:00',
        locationName: 'Hard Rock Cafe, Bến Nghé Q1',
        coverImageUrl: 'https://lh3.googleusercontent.com/aida-public/AB6AXuCHvQQo3rlkT-_-4tUHI3g57mTvXFLLtgJIrPL-reMGuj3XaOw5i6m8XE6UGxWKt-QuWxbS2cGCGQjYHDt8EDrRooC6YbzU-eaPUv9DcCue5-MmAQR68oLBY_jSWFWP-C4xOAdAv4AxulL_cS5HPJAIgKYoERtOuwFAt7Adc_XIULWFK-BBSXPXfPg5aXY3f55MNtosKA6Nk4dKNOiGKA4Obe8EMj5iC0bffRUXPj_BkbYJEu63krqF',
        isLive: true,
      ),
      EventModel(
        id: 'evt-3',
        title: 'Sub-Zero Bass Fest: Phase 2',
        categoryName: 'GLOBAL BASS COLLECTIVE',
        minPrice: 380000,
        startDate: 'Sat, Jan 11 • 21:30',
        locationName: 'The Warehouse 204, Thủ Đức',
        coverImageUrl: 'https://lh3.googleusercontent.com/aida-public/AB6AXuAXF1myZ7dVayjdjsY9cXbThsHvczZKU-JKBTR7f-4z4ZOMXjt1cIuOadRJajuvCIlvfE5TORdJAlcx5PnTyx-8HFnEKzjrG9uHtYccztPIeJD2-ZrLxKajcrT6LnALtmvbPYYOuH-Hzj7IKeqnsnQOygu58dnRikxGlxoqo45sQ7EYG1H9OZp8Tg54ngoxw5KjE_1H8bRa4QLKibNXZTd9UGUoyZzY-LK7oZGNxbr1S9NOYsVZJLMr',
      ),
    ];
  }

  Future<EventModel> getEventDetail(String id) async {
    final response = await ApiClient().get('${ApiConfig.events}/$id');
    if (response['success'] == true && response['data'] != null) {
      return EventModel.fromJson(response['data']);
    }
    final all = await getPublicEvents();
    return all.firstWhere(
      (e) => e.id == id,
      orElse: () => all.first,
    );
  }
}
