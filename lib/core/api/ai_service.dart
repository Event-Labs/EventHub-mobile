import 'api_client.dart';
import 'api_config.dart';
import '../models/event_model.dart';

class AiChatMessage {
  final String role; // 'user' or 'assistant'
  final String content;
  final DateTime timestamp;

  AiChatMessage({
    required this.role,
    required this.content,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  factory AiChatMessage.fromJson(Map<String, dynamic> json) {
    return AiChatMessage(
      role: json['role']?.toString() ?? 'assistant',
      content: json['content']?.toString() ?? '',
      timestamp: json['timestamp'] != null
          ? DateTime.tryParse(json['timestamp'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'role': role,
      'content': content,
      'timestamp': timestamp.toIso8601String(),
    };
  }
}

class AiChatSession {
  final String id;
  String title;
  final int createdAt;
  int updatedAt;
  List<AiChatMessage> messages;

  AiChatSession({
    required this.id,
    required this.title,
    required this.createdAt,
    required this.updatedAt,
    required this.messages,
  });

  factory AiChatSession.createDefault() {
    final now = DateTime.now().millisecondsSinceEpoch;
    return AiChatSession(
      id: 'session_${now}_${(1000 + (now % 9000))}',
      title: 'Đoạn chat mới',
      createdAt: now,
      updatedAt: now,
      messages: [
        AiChatMessage(
          role: 'assistant',
          content: 'Xin chào! Tôi là trợ lý AI của EventHub. Tôi có thể giúp bạn tìm kiếm sự kiện, kiểm tra giá vé, trạng thái đơn hàng và các chính sách khác.',
        ),
      ],
    );
  }

  factory AiChatSession.fromJson(Map<String, dynamic> json) {
    final msgList = json['messages'] is List ? (json['messages'] as List) : [];
    return AiChatSession(
      id: json['id']?.toString() ?? json['sessionId']?.toString() ?? 'session_${DateTime.now().millisecondsSinceEpoch}',
      title: json['title']?.toString() ?? 'Đoạn chat mới',
      createdAt: int.tryParse(json['createdAt']?.toString() ?? '') ?? DateTime.now().millisecondsSinceEpoch,
      updatedAt: int.tryParse(json['updatedAt']?.toString() ?? '') ?? DateTime.now().millisecondsSinceEpoch,
      messages: msgList.map((m) => AiChatMessage.fromJson(m is Map<String, dynamic> ? m : Map<String, dynamic>.from(m))).toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'sessionId': id,
      'title': title,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
      'messages': messages.map((m) => m.toJson()).toList(),
    };
  }
}

class AiChatResponse {
  final String text;
  final String rawContent;
  final List<EventModel> suggestedEvents;

  AiChatResponse({
    required this.text,
    required this.rawContent,
    this.suggestedEvents = const [],
  });
}

class AiService {
  static final AiService _instance = AiService._internal();
  factory AiService() => _instance;
  AiService._internal();

  /// Sends a chat message to backend /api/ai-assistant/chat
  Future<AiChatResponse> sendChatMessage(
    String message, {
    List<Map<String, String>> history = const [],
    String? sessionId,
    String? title,
  }) async {
    final response = await ApiClient().post(ApiConfig.aiChat, {
      'message': message,
      'history': history,
      'sessionId': sessionId ?? 'mobile_session',
      'title': title,
    });

    if (response['success'] == true && response['data'] != null) {
      final data = response['data'];
      final rawContent = data['content']?.toString() ?? data['answer']?.toString() ?? 'Eve đã tiếp nhận thông tin của bạn!';
      List<EventModel> events = [];
      if (data['suggestedEvents'] is List) {
        events = (data['suggestedEvents'] as List).map((e) => EventModel.fromJson(e)).toList();
      }

      return AiChatResponse(
        text: rawContent,
        rawContent: rawContent,
        suggestedEvents: events,
      );
    }

    // Fallback response if offline or cold start
    final fallback = _generateSmartFallback(message);
    return AiChatResponse(text: fallback, rawContent: fallback);
  }

  /// Fetches saved sessions for authenticated user from DB
  Future<List<AiChatSession>> getSessions() async {
    final response = await ApiClient().get(ApiConfig.aiSessions);
    if (response['success'] == true && response['data'] is List) {
      final List list = response['data'];
      return list.map((e) => AiChatSession.fromJson(e)).toList();
    }
    return [];
  }

  /// Saves or upserts a session to backend DB
  Future<bool> saveSession(AiChatSession session) async {
    final response = await ApiClient().post(ApiConfig.aiSessions, session.toJson());
    return response['success'] == true;
  }

  /// Deletes a session from backend DB
  Future<bool> deleteSession(String sessionId) async {
    final response = await ApiClient().delete(ApiConfig.deleteAiSession(sessionId));
    return response['success'] == true;
  }

  String _generateSmartFallback(String message) {
    final q = message.toLowerCase();
    if (q.contains('check-in') || q.contains('quét') || q.contains('qr') || q.contains('vào cổng')) {
      return '🎫 **Hướng dẫn Check-in tại sự kiện:**\n\n'
          '1. Mở ứng dụng EventHub, vào mục **"Vé của tôi"** ở thanh điều hướng dưới cùng.\n'
          '2. Bấm vào nút **"Mã QR"** hoặc chọn vé để mở giao diện toàn màn hình.\n'
          '3. Xuất trình mã QR cho nhân viên soát vé tại cổng để quét.\n'
          '4. Bạn cũng có thể tải ảnh vé (PNG) về máy để check-in ngay cả khi không có kết nối internet nhé!';
    } else if (q.contains('hoàn') || q.contains('hủy') || q.contains('refund') || q.contains('trả vé')) {
      return '💸 **Chính sách & Quy trình Hoàn vé:**\n\n'
          '• Bạn có thể gửi yêu cầu hoàn vé trực tiếp tại trang **"Chi Tiết Vé"**.\n'
          '• Điều kiện: Vé phải ở trạng thái Hợp lệ và gửi yêu cầu trước thời hạn quy định trong Refund Policy của từng sự kiện.\n'
          '• Số tiền hoàn sẽ được chuyển về tài khoản ngân hàng bạn cung cấp sau khi Ban tổ chức xét duyệt (thường từ 1-3 ngày làm việc).';
    } else if (q.contains('thanh toán') || q.contains('pay') || q.contains('ngân hàng') || q.contains('chuyển khoản')) {
      return '💳 **Phương thức Thanh toán hỗ trợ:**\n\n'
          '• EventHub tích hợp cổng thanh toán an toàn **PayOS** (hỗ trợ quét mã VietQR qua tất cả ứng dụng ngân hàng và ví điện tử).\n'
          '• Sau khi thanh toán thành công, vé điện tử và hóa đơn sẽ được xuất tự động ngay lập tức vào mục "Vé của tôi".';
    } else if (q.contains('sự kiện') || q.contains('hot') || q.contains('âm nhạc') || q.contains('show')) {
      return '✨ **Sự kiện nổi bật tại EventHub:**\n\n'
          'Hiện có rất nhiều sự kiện âm nhạc, hội thảo và festival bùng nổ như:\n'
          '• **Neon Horizon Festival 2025** (EDM & Light show đỉnh cao tại SECC Q7)\n'
          '• **The Nocturnal Acoustic Echoes** (Đêm nhạc acoustic ấm cúng)\n\n'
          'Bạn có thể ghé mục **"Khám phá"** trên ứng dụng để xem chi tiết và đặt vé ngay nhé!';
    }

    return 'Xin chào bạn! Tôi là trợ lý AI của EventHub. 🥰\n\n'
        'Tôi có thể hỗ trợ bạn tìm kiếm sự kiện, tra cứu thông tin vé, hướng dẫn check-in QR và các chính sách thanh toán, hoàn vé.\n\n'
        'Bạn đang cần hỗ trợ vấn đề gì ạ?';
  }
}
