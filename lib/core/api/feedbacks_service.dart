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
    return [];
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
