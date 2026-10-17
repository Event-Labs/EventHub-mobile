import 'api_client.dart';
import 'api_config.dart';
import '../models/event_model.dart';

class AiChatResponse {
  final String text;
  final List<EventModel> suggestedEvents;

  AiChatResponse({required this.text, this.suggestedEvents = const []});
}

class AiService {
  static final AiService _instance = AiService._internal();
  factory AiService() => _instance;
  AiService._internal();

  Future<AiChatResponse> askGenie(String question, {List<Map<String, String>> history = const []}) async {
    final response = await ApiClient().post(ApiConfig.aiChat, {
      'message': question,
      'history': history,
      'sessionId': 'mobile-session',
    });

    if (response['success'] == true && response['data'] != null) {
      final data = response['data'];
      final content = data['content']?.toString() ?? data['answer']?.toString() ?? 'Dạ, tôi có thể hỗ trợ gì cho bạn?';
      List<EventModel> events = [];
      if (data['suggestedEvents'] is List) {
        events = (data['suggestedEvents'] as List).map((e) => EventModel.fromJson(e)).toList();
      }
      return AiChatResponse(text: content, suggestedEvents: events);
    }

    // Smart fallback answer for demo
    String fallbackText;
    if (question.toLowerCase().contains('vé') || question.toLowerCase().contains('giá')) {
      fallbackText = 'Vé các sự kiện âm nhạc tại EventHub dao động từ 180.000đ đến 450.000đ. Bạn có thể chọn loại vé VIP hoặc Standard trong chi tiết sự kiện!';
    } else if (question.toLowerCase().contains('check-in') || question.toLowerCase().contains('qr')) {
      fallbackText = 'Để check-in vào sự kiện, bạn chỉ cần mở mục "Vé của tôi", bấm vào vé để hiện mã QR code lớn cho nhân viên soát vé quét tại cổng!';
    } else if (question.toLowerCase().contains('hoàn') || question.toLowerCase().contains('hủy')) {
      fallbackText = 'Bạn có thể gửi yêu cầu hoàn vé ngay trong màn hình Chi tiết vé nếu sự kiện chưa bắt đầu và ban tổ chức cho phép hoàn trả theo chính sách!';
    } else {
      fallbackText = 'Xin chào! Tôi là Trợ lý AI EventHub. Tôi có thể hỗ trợ bạn tìm kiếm sự kiện, tra cứu thông tin vé, lịch diễn và các chính sách ưu đãi.';
    }

    return AiChatResponse(text: fallbackText);
  }
}
