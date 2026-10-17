import 'api_client.dart';
import 'api_config.dart';

class NotificationModel {
  final String id;
  final String title;
  final String message;
  final String? type;
  final bool isRead;
  final String? createdAt;
  final String? eventId;
  final String? eventTitle;
  final Map<String, dynamic>? data;

  NotificationModel({
    required this.id,
    required this.title,
    required this.message,
    this.type,
    this.isRead = false,
    this.createdAt,
    this.eventId,
    this.eventTitle,
    this.data,
  });

  factory NotificationModel.fromJson(Map<String, dynamic> json) {
    return NotificationModel(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? 'Thông báo',
      message: json['message']?.toString() ?? json['content']?.toString() ?? '',
      type: json['type']?.toString(),
      isRead: json['is_read'] == true || json['read'] == true,
      createdAt: json['created_at']?.toString(),
      eventId: json['event_id']?.toString() ?? (json['event'] is Map ? json['event']['id']?.toString() : null),
      eventTitle: json['event_title']?.toString() ?? (json['event'] is Map ? json['event']['title']?.toString() : null),
      data: json['data'] is Map ? json['data'] : null,
    );
  }
}

class NotificationsService {
  static final NotificationsService _instance = NotificationsService._internal();
  factory NotificationsService() => _instance;
  NotificationsService._internal();

  Future<List<NotificationModel>> getNotifications() async {
    final response = await ApiClient().get(ApiConfig.notifications);
    if (response['success'] == true && response['data'] != null) {
      final List list = response['data'] is List
          ? response['data']
          : (response['data']['items'] ?? response['data']['notifications'] ?? []);
      return list.map((e) => NotificationModel.fromJson(e)).toList();
    }
    return [
      NotificationModel(
        id: 'noti-1',
        title: 'Đặt vé thành công',
        message: 'Bạn đã đặt vé VIP cho Neon Horizon Festival 2025. Hãy kiểm tra ví vé để chuẩn bị check-in.',
        type: 'ORDER_SUCCESS',
        isRead: false,
        createdAt: DateTime.now().subtract(const Duration(hours: 2)).toIso8601String(),
      ),
      NotificationModel(
        id: 'noti-2',
        title: 'Nhắc nhở sự kiện',
        message: 'Sự kiện Neon Horizon Festival sẽ bắt đầu sau 3 ngày nữa tại SECC Quận 7.',
        type: 'EVENT_REMINDER',
        isRead: true,
        createdAt: DateTime.now().subtract(const Duration(days: 1)).toIso8601String(),
      ),
    ];
  }

  Future<int> getUnreadCount() async {
    final response = await ApiClient().get(ApiConfig.notificationsUnreadCount);
    if (response['success'] == true && response['data'] != null) {
      if (response['data'] is Map) {
        return int.tryParse(response['data']['count']?.toString() ?? '0') ?? 0;
      }
      return int.tryParse(response['data'].toString()) ?? 0;
    }
    return 1;
  }

  Future<bool> markAsRead(String id) async {
    final response = await ApiClient().patch(ApiConfig.markNotificationRead(id), {});
    return response['success'] == true;
  }

  Future<bool> markAllAsRead() async {
    final response = await ApiClient().patch(ApiConfig.notificationsReadAll, {});
    return response['success'] == true;
  }
}
