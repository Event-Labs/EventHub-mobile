import 'api_client.dart';
import 'api_config.dart';

class EligibleFeedbackEventModel {
  final String id;
  final String title;
  final String? bannerUrl;
  final String? date;

  EligibleFeedbackEventModel({
    required this.id,
    required this.title,
    this.bannerUrl,
    this.date,
  });

  factory EligibleFeedbackEventModel.fromJson(Map<String, dynamic> json) {
    return EligibleFeedbackEventModel(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? 'Sự kiện đã tham gia',
      bannerUrl: json['banner_url']?.toString() ?? json['thumbnail_url']?.toString(),
      date: json['date']?.toString() ?? json['start_time']?.toString(),
    );
  }
}

class FeedbacksService {
  static final FeedbacksService _instance = FeedbacksService._internal();
  factory FeedbacksService() => _instance;
  FeedbacksService._internal();

  Future<List<EligibleFeedbackEventModel>> getEligibleEvents() async {
    final response = await ApiClient().get(ApiConfig.feedbackEligible);
    if (response['success'] == true && response['data'] != null) {
      final List list = response['data'] is List ? response['data'] : [];
      return list.map((e) => EligibleFeedbackEventModel.fromJson(e)).toList();
    }
    return [
      EligibleFeedbackEventModel(
        id: 'evt-2',
        title: 'The Nocturnal Acoustic Echoes',
        bannerUrl: 'https://images.unsplash.com/photo-1511671782779-c97d3d27a1d4?auto=format&fit=crop&w=1200&q=80',
        date: '03/01/2026',
      ),
    ];
  }

  Future<Map<String, dynamic>> submitFeedback({
    required String eventId,
    required int rating,
    required String content,
  }) async {
    final response = await ApiClient().post(ApiConfig.feedbacks, {
      'event_id': eventId,
      'rating': rating,
      'content': content,
    });

    if (response['success'] == true) {
      return {
        'success': true,
        'message': response['message'] ?? 'Gửi đánh giá thành công! Cảm ơn bạn.',
      };
    }
    return {
      'success': false,
      'message': response['message'] ?? 'Không thể gửi đánh giá',
    };
  }
}
