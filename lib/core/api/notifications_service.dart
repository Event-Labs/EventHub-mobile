import 'package:intl/intl.dart';
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
      type: json['type']?.toString().toUpperCase(),
      isRead: json['is_read'] == true || json['read'] == true,
      createdAt: json['created_at']?.toString(),
      eventId: json['event_id']?.toString() ?? (json['event'] is Map ? json['event']['id']?.toString() : null),
      eventTitle: json['event_title']?.toString() ?? (json['event'] is Map ? json['event']['title']?.toString() : null),
      data: json['data'] is Map ? json['data'] : null,
    );
  }

  bool get isEventReminder {
    if (type == 'EVENT_REMINDER' || type == 'REMINDER') return true;
    final lowerTitle = title.toLowerCase();
    final lowerMsg = message.toLowerCase();
    return lowerTitle.contains('nhắc') || lowerTitle.contains('sắp diễn') || lowerMsg.contains('bắt đầu lúc') || lowerMsg.contains('chuẩn bị check-in');
  }

  bool get isPaymentOrTicket {
    return type == 'PAYMENT' || type == 'ORDER_SUCCESS' || type == 'TICKET' || type == 'REFUND';
  }

  String get formattedTime {
    if (createdAt == null) return '';
    try {
      final date = DateTime.parse(createdAt!);
      final now = DateTime.now();
      final diff = now.difference(date);

      if (diff.inMinutes < 60) {
        return diff.inMinutes <= 1 ? 'Vừa xong' : '${diff.inMinutes} phút trước';
      }
      if (diff.inHours < 24) {
        return '${diff.inHours} giờ trước';
      }
      if (diff.inDays < 7) {
        return '${diff.inDays} ngày trước';
      }
      return DateFormat('HH:mm • dd/MM/yyyy').format(date);
    } catch (_) {
      return createdAt!;
    }
  }
}

class NotificationsService {
  static final NotificationsService _instance = NotificationsService._internal();
  factory NotificationsService() => _instance;
  NotificationsService._internal();

  Future<List<NotificationModel>> getNotifications({String? category}) async {
    final Map<String, String> params = {'limit': '50', 'page': '1'};
    if (category != null && category.isNotEmpty) {
      params['category'] = category;
    }

    final response = await ApiClient().get(ApiConfig.notifications, queryParams: params);
    if (response['success'] == true && response['data'] != null) {
      final List list = response['data'] is List
          ? response['data']
          : (response['data']['items'] ?? response['data']['notifications'] ?? []);
      return list.map((e) => NotificationModel.fromJson(e)).toList();
    }
    return [];
  }

  Future<int> getUnreadCount() async {
    final response = await ApiClient().get(ApiConfig.notificationsUnreadCount);
    if (response['success'] == true && response['data'] != null) {
      if (response['data'] is Map) {
        final unread = response['data']['unread_count'] ?? response['data']['count'];
        return int.tryParse(unread?.toString() ?? '0') ?? 0;
      }
      return int.tryParse(response['data'].toString()) ?? 0;
    }
    return 0;
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
