import 'package:flutter/material.dart';
import '../../../../core/api/auth_service.dart';
import '../../../../core/api/notifications_service.dart';
import '../../../auth/presentation/pages/login_page.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_background.dart';
import '../../../home/presentation/pages/event_detail_page.dart';
import '../../../tickets/presentation/pages/my_tickets_page.dart';

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  List<NotificationModel> _notifications = [];
  bool _isLoading = true;
  int _selectedTabIndex = 0; // 0: Tất cả, 1: Nhắc lịch sự kiện, 2: Vé & Giao dịch

  @override
  void initState() {
    super.initState();
    if (AuthService().currentUser != null && AuthService().isLoggedIn) {
      _loadNotifications();
    } else {
      _isLoading = false;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const LoginPage()),
        );
      });
    }
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
        const SnackBar(
          content: Text('Đã đánh dấu tất cả thông báo là đã đọc'),
          backgroundColor: Color(0xFF22C55E),
        ),
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

    // Deep navigation based on notification type
    if (item.isEventReminder && item.eventId != null && item.eventId!.isNotEmpty) {
      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => EventDetailPage(eventId: item.eventId!),
          ),
        );
      }
    } else if (item.isPaymentOrTicket) {
      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => const MyTicketsPage(),
          ),
        );
      }
    }
  }

  List<NotificationModel> get _filteredNotifications {
    if (_selectedTabIndex == 1) {
      return _notifications.where((n) => n.isEventReminder).toList();
    }
    if (_selectedTabIndex == 2) {
      return _notifications.where((n) => n.isPaymentOrTicket).toList();
    }
    return _notifications;
  }

  @override
  Widget build(BuildContext context) {
    if (AuthService().currentUser == null || !AuthService().isLoggedIn) {
      return AppBackground(
        child: Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            surfaceTintColor: Colors.transparent,
            elevation: 0,
            title: const Text(
              'Thông Báo',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 20),
            ),
          ),
        body: Center(
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
                    border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                  ),
                  child: const Icon(Icons.notifications_none, color: Color(0xFFE6C17A), size: 48),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Vui lòng đăng nhập để xem thông báo của bạn.',
                  style: TextStyle(color: Color(0xFFB0CADD), fontSize: 14),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                Container(
                  height: 48,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFC99A47), Color(0xFFE6C17A)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFC99A47).withValues(alpha: 0.35),
                        blurRadius: 16,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(24),
                      onTap: () {
                        Navigator.of(context).pushReplacement(
                          MaterialPageRoute(builder: (_) => const LoginPage()),
                        );
                      },
                      child: const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 28),
                        child: Center(
                          child: Text(
                            'Đăng Nhập Ngay',
                            style: TextStyle(color: Color(0xFF0D1B2A), fontWeight: FontWeight.bold, fontSize: 15),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

    final unreadCount = _notifications.where((n) => !n.isRead).length;
    final items = _filteredNotifications;

    return AppBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Thông Báo',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 20),
            ),
            Text(
              'Nhắc nhở sự kiện, vé & cập nhật hệ thống',
              style: TextStyle(color: Color(0xFF8B9CB5), fontSize: 11),
            ),
          ],
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
      body: Column(
        children: [
          // Filter Tabs
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: const Color(0xFF101932),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  _buildTabItem(0, 'Tất cả'),
                  _buildTabItem(1, 'Nhắc lịch sự kiện'),
                  _buildTabItem(2, 'Vé & Đơn hàng'),
                ],
              ),
            ),
          ),

          // Notification List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: AppColors.primaryContainer))
                : items.isEmpty
                    ? _buildEmptyState()
                    : RefreshIndicator(
                        color: AppColors.primaryContainer,
                        backgroundColor: const Color(0xFF101932),
                        onRefresh: _loadNotifications,
                        child: ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          itemCount: items.length,
                          itemBuilder: (ctx, idx) {
                            final item = items[idx];
                            return _buildNotificationItem(item);
                          },
                        ),
                      ),
          ),
        ],
      ),
    ),
  );
  }

  Widget _buildTabItem(int index, String label) {
    final isSelected = _selectedTabIndex == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedTabIndex = index),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.primaryContainer : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: isSelected ? Colors.white : const Color(0xFFB0CADD),
              fontSize: 12,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNotificationItem(NotificationModel item) {
    IconData icon;
    Color iconColor;

    if (item.isEventReminder) {
      icon = Icons.alarm;
      iconColor = const Color(0xFF06B6D4);
    } else {
      switch (item.type) {
        case 'PAYMENT':
        case 'ORDER_SUCCESS':
          icon = Icons.local_activity;
          iconColor = const Color(0xFF22C55E);
          break;
        case 'REFUND':
          icon = Icons.replay;
          iconColor = const Color(0xFFF59E0B);
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
    }

    return GestureDetector(
      onTap: () => _handleTapNotification(item),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: item.isRead ? const Color(0xFF101932).withValues(alpha: 0.6) : const Color(0xFF152244),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: item.isEventReminder && !item.isRead
                ? const Color(0xFF06B6D4).withValues(alpha: 0.5)
                : item.isRead
                    ? Colors.white.withValues(alpha: 0.06)
                    : AppColors.primaryContainer.withValues(alpha: 0.35),
            width: item.isEventReminder && !item.isRead ? 1.5 : 1,
          ),
          boxShadow: [
            if (!item.isRead)
              BoxShadow(
                color: (item.isEventReminder ? const Color(0xFF06B6D4) : AppColors.primaryContainer).withValues(alpha: 0.1),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.15),
                shape: BoxShape.circle,
                border: Border.all(color: iconColor.withValues(alpha: 0.4)),
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
                          margin: const EdgeInsets.only(left: 6),
                          decoration: BoxDecoration(
                            color: item.isEventReminder ? const Color(0xFF06B6D4) : AppColors.primaryContainer,
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
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        item.formattedTime,
                        style: const TextStyle(color: Color(0xFF64748B), fontSize: 11),
                      ),
                      if (item.isEventReminder || item.isPaymentOrTicket)
                        Row(
                          children: [
                            Text(
                              item.isEventReminder ? 'Xem sự kiện' : 'Xem vé',
                              style: TextStyle(
                                color: iconColor,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(width: 2),
                            Icon(Icons.chevron_right, color: iconColor, size: 14),
                          ],
                        ),
                    ],
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
    String emptyTitle = 'Không có thông báo mới';
    String emptySubtitle = 'Các cập nhật về vé đã đặt, lịch biểu diễn và thông báo từ ban tổ chức sẽ xuất hiện ở đây.';

    if (_selectedTabIndex == 1) {
      emptyTitle = 'Chưa có nhắc nhở lịch sự kiện nào';
      emptySubtitle = 'Hệ thống sẽ tự động nhắc nhở bạn trước 24 giờ và trước giờ bắt đầu của các sự kiện bạn đã mua vé.';
    } else if (_selectedTabIndex == 2) {
      emptyTitle = 'Chưa có thông báo vé & đơn hàng';
      emptySubtitle = 'Thông tin xác nhận thanh toán và cập nhật tình trạng vé sẽ được gửi tới bạn tại đây.';
    }

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
                border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
              ),
              child: Icon(
                _selectedTabIndex == 1 ? Icons.alarm_off : Icons.notifications_none,
                color: AppColors.secondary,
                size: 48,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              emptyTitle,
              style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              emptySubtitle,
              style: const TextStyle(color: Color(0xFFB0CADD), fontSize: 13, height: 1.4),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
