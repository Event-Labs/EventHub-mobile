import 'api_client.dart';
import 'api_config.dart';

class AiService {
  static final AiService _instance = AiService._internal();
  factory AiService() => _instance;
  AiService._internal();

  Future<String> askGenie(String question) async {
    final response = await ApiClient().post(ApiConfig.aiFaq, {
      'question': question,
    });

    if (response['success'] == true && response['data'] != null) {
      return response['data']['answer']?.toString() ?? response['data']?.toString() ?? 'Dạ, EventHub Genie có thể giúp gì cho bạn?';
    }

    // Smart fallback answer for demo
    if (question.toLowerCase().contains('vé') || question.toLowerCase().contains('giá')) {
      return 'Vé các sự kiện âm nhạc tại EventHub dao động từ 250.000đ đến 450.000đ. Bạn có thể chọn loại vé VIP hoặc Standard trong chi tiết sự kiện!';
    }
    if (question.toLowerCase().contains('check-in') || question.toLowerCase().contains('qr')) {
      return 'Để check-in vào sự kiện, bạn chỉ cần mở mục "Vé của tôi", bấm vào vé để hiện mã QR code lớn cho nhân viên soát vé quét tại cổng!';
    }
    return 'Xin chào! Tôi là Trợ lý AI EventHub. Tôi có thể hỗ trợ bạn tìm kiếm sự kiện, tra cứu thông tin vé, lịch diễn và các chính sách ưu đãi.';
  }
}
