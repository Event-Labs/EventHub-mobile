import 'package:flutter/material.dart';
import '../../../../core/api/notifications_service.dart';
import '../../../../core/theme/app_colors.dart';

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  List<NotificationModel> _notifications = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadNotifications();
  }

  Future<void> _loadNotifications() async {
    setState(() => _isLoading = true);
    final list = await NotificationsService().getNotifications();
    if (mounted) {
      setState(() {
        _notifications = list;
        _isLoading = false;
      });
    }
  }

  Future<void> _handleMarkAllRead() async {
    final success = await NotificationsService().markAllAsRead();
    if (success && mounted) {
      setState(() {
        _notifications = _notifications.map((n) => NotificationModel(
          id: n.id,
          title: n.title,
          message: n.message,
          type: n.type,
          isRead: true,
          createdAt: n.createdAt,
          eventId: n.eventId,
          eventTitle: n.eventTitle,
          data: n.data,
        )).toList();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đã đánh dấu tất cả là đã đọc'), backgroundColor: Colors.green),
      );
    }
  }

  Future<void> _handleTapNotification(NotificationModel item) async {
    if (!item.isRead) {
      await NotificationsService().markAsRead(item.id);
      setState(() {
        final idx = _notifications.indexWhere((n) => n.id == item.id);
        if (idx != -1) {
          _notifications[idx] = NotificationModel(
            id: item.id,
            title: item.title,
            message: item.message,
            type: item.type,
            isRead: true,
            createdAt: item.createdAt,
            eventId: item.eventId,
            eventTitle: item.eventTitle,
            data: item.data,
          );
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final unreadCount = _notifications.where((n) => !n.isRead).length;

    return Scaffold(
      backgroundColor: const Color(0xFF070D1E),
      appBar: AppBar(
        backgroundColor: const Color(0xFF070D1E),
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'Thông Báo',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 20),
        ),
        actions: [
          if (unreadCount > 0)
            TextButton.icon(
              onPressed: _handleMarkAllRead,
              icon: const Icon(Icons.done_all, color: AppColors.primaryContainer, size: 18),
              label: const Text(
                'Đọc tất cả',
                style: TextStyle(color: AppColors.primaryContainer, fontSize: 13, fontWeight: FontWeight.bold),
              ),
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primaryContainer))
          : _notifications.isEmpty
              ? _buildEmptyState()
              : RefreshIndicator(
                  color: AppColors.primaryContainer,
                  backgroundColor: const Color(0xFF101932),
                  onRefresh: _loadNotifications,
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    itemCount: _notifications.length,
                    itemBuilder: (ctx, idx) {
                      final item = _notifications[idx];
                      return _buildNotificationItem(item);
                    },
                  ),
                ),
    );
  }

  Widget _buildNotificationItem(NotificationModel item) {
    IconData icon;
    Color iconColor;
    switch (item.type) {
      case 'ORDER_SUCCESS':
        icon = Icons.local_activity;
        iconColor = const Color(0xFF22C55E);
        break;
      case 'EVENT_REMINDER':
        icon = Icons.alarm;
        iconColor = const Color(0xFF06B6D4);
        break;
      case 'STAFF_INVITATION':
        icon = Icons.badge;
        iconColor = const Color(0xFFE6C17A);
        break;
      default:
        icon = Icons.notifications;
        iconColor = AppColors.primaryContainer;
        break;
    }

    return GestureDetector(
      onTap: () => _handleTapNotification(item),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: item.isRead ? const Color(0xFF101932).withOpacity(0.6) : const Color(0xFF152244),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: item.isRead ? Colors.white.withOpacity(0.06) : AppColors.primaryContainer.withOpacity(0.35),
            width: 1,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: iconColor.withOpacity(0.15),
                shape: BoxShape.circle,
                border: Border.all(color: iconColor.withOpacity(0.4)),
              ),
              child: Icon(icon, color: iconColor, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          item.title,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: item.isRead ? FontWeight.w600 : FontWeight.bold,
                          ),
                        ),
                      ),
                      if (!item.isRead)
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: AppColors.primaryContainer,
                            shape: BoxShape.circle,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    item.message,
                    style: TextStyle(
                      color: item.isRead ? const Color(0xFF8B9CB5) : const Color(0xFFDAE2FF),
                      fontSize: 13,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: const Color(0xFF101932),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white.withOpacity(0.08)),
              ),
              child: const Icon(Icons.notifications_none, color: AppColors.secondary, size: 48),
            ),
            const SizedBox(height: 20),
            const Text(
              'Không có thông báo mới',
              style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Các cập nhật về vé đã đặt, lịch chiếu và thông báo từ ban tổ chức sẽ xuất hiện ở đây.',
              style: TextStyle(color: Color(0xFFB0CADD), fontSize: 13, height: 1.4),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
