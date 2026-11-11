import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../core/models/event_model.dart';
import '../../../../core/widgets/app_background.dart';
import '../../../tickets/presentation/pages/my_tickets_page.dart';

class PaymentSuccessPage extends StatelessWidget {
  final String orderId;
  final Map<String, dynamic>? orderData;
  final EventModel? event;
  final String? buyerName;
  final String? buyerEmail;
  final String? buyerPhone;
  final int? totalQuantity;
  final double? finalPrice;

  const PaymentSuccessPage({
    super.key,
    required this.orderId,
    this.orderData,
    this.event,
    this.buyerName,
    this.buyerEmail,
    this.buyerPhone,
    this.totalQuantity,
    this.finalPrice,
  });

  String _formatCurrency(double amount) {
    if (amount == 0) return '0đ (Miễn phí)';
    final formatter = NumberFormat.currency(locale: 'vi_VN', symbol: 'đ', decimalDigits: 0);
    return formatter.format(amount);
  }

  @override
  Widget build(BuildContext context) {
    final order = (orderData?['order'] is Map)
        ? (orderData!['order'] as Map<String, dynamic>)
        : (orderData ?? {});

    final orderCode = order['order_code']?.toString() ??
        order['code']?.toString() ??
        (orderId.length > 8 ? orderId.substring(0, 8).toUpperCase() : orderId.toUpperCase());

    final name = buyerName ?? order['buyer_name']?.toString() ?? 'Quý khách';
    final email = buyerEmail ?? order['buyer_email']?.toString() ?? '';
    final phone = buyerPhone ?? order['buyer_phone']?.toString() ?? '';

    final num? rawTotal = order['total_amount'] as num? ??
        order['total_price'] as num? ??
        finalPrice;
    final double amount = (rawTotal ?? 0).toDouble();

    final int qty = totalQuantity ??
        (order['items'] is List ? (order['items'] as List).length : 1);

    final eventTitle = event?.title ?? order['event']?['title']?.toString() ?? 'Sự kiện EventHub';
    final eventLocation = event?.venue?.summary ??
        event?.venue?.addressLine ??
        event?.venue?.name ??
        order['event']?['location']?.toString() ??
        'Địa điểm xem chi tiết trên vé';
    final eventTime = event?.formattedDateTime ?? 'Theo lịch đã chọn';

    return AppBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: Column(
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: IconButton(
                        icon: const Icon(Icons.close, color: Colors.white),
                        tooltip: 'Về trang chủ',
                        onPressed: () {
                          Navigator.of(context).popUntil((route) => route.isFirst);
                        },
                      ),
                    ),
                    const Expanded(
                      child: Text(
                        'Kết Quả Đặt Vé',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 48), // Balance close button
                  ],
                ),
              ),

              // Content
              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  child: Column(
                    children: [
                      const SizedBox(height: 10),

                      // Success Animation Icon
                      Container(
                        width: 90,
                        height: 90,
                        decoration: BoxDecoration(
                          color: const Color(0xFF22C55E).withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: const Color(0xFF22C55E),
                            width: 3,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF22C55E).withValues(alpha: 0.3),
                              blurRadius: 24,
                              spreadRadius: 4,
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.check_rounded,
                          color: Color(0xFF22C55E),
                          size: 52,
                        ),
                      ),

                      const SizedBox(height: 20),

                      // Main Title
                      Text(
                        amount == 0 ? 'NHẬN VÉ THÀNH CÔNG!' : 'THANH TOÁN THÀNH CÔNG!',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.3,
                        ),
                      ),

                      const SizedBox(height: 6),
                      Text(
                        amount == 0
                            ? 'Bạn đã đăng ký vé tham dự sự kiện miễn phí thành công.'
                            : 'Đơn hàng của bạn đã hoàn tất và vé đã được phát hành.',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Color(0xFFB0CADD),
                          fontSize: 13,
                        ),
                      ),

                      const SizedBox(height: 24),

                      // Order Summary Card
                      Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0C142A).withValues(alpha: 0.9),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.4),
                              blurRadius: 16,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Event Information
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  width: 44,
                                  height: 44,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFE6C17A).withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: const Color(0xFFE6C17A).withValues(alpha: 0.4)),
                                  ),
                                  child: const Icon(Icons.festival_rounded, color: Color(0xFFE6C17A), size: 24),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        eventTitle,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 15,
                                          fontWeight: FontWeight.bold,
                                        ),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 4),
                                      Row(
                                        children: [
                                          const Icon(Icons.access_time, color: Color(0xFF8B9CB5), size: 13),
                                          const SizedBox(width: 4),
                                          Expanded(
                                            child: Text(
                                              eventTime,
                                              style: const TextStyle(color: Color(0xFF8B9CB5), fontSize: 12),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 3),
                                      Row(
                                        children: [
                                          const Icon(Icons.location_on_outlined, color: Color(0xFF8B9CB5), size: 13),
                                          const SizedBox(width: 4),
                                          Expanded(
                                            child: Text(
                                              eventLocation,
                                              style: const TextStyle(color: Color(0xFF8B9CB5), fontSize: 12),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),

                            const Divider(color: Colors.white12, height: 26),

                            // Detail items
                            _buildInfoRow('Mã đơn hàng', orderCode, isMonospace: true, isHighlight: true),
                            const SizedBox(height: 10),
                            _buildInfoRow('Trạng thái', 'Đã xác nhận', badgeColor: const Color(0xFF22C55E)),
                            const SizedBox(height: 10),
                            _buildInfoRow('Người đặt vé', name),
                            if (email.isNotEmpty) ...[
                              const SizedBox(height: 10),
                              _buildInfoRow('Email', email),
                            ],
                            if (phone.isNotEmpty) ...[
                              const SizedBox(height: 10),
                              _buildInfoRow('Điện thoại', phone),
                            ],
                            const SizedBox(height: 10),
                            _buildInfoRow('Số lượng vé', '$qty vé'),
                            const SizedBox(height: 10),
                            _buildInfoRow(
                              'Tổng thanh toán',
                              amount == 0 ? 'Miễn phí' : _formatCurrency(amount),
                              valueColor: const Color(0xFFE6C17A),
                              isBold: true,
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 16),

                      // Notice Box
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFF06B6D4).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0xFF06B6D4).withValues(alpha: 0.3)),
                        ),
                        child: const Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(Icons.info_outline_rounded, color: Color(0xFF06B6D4), size: 20),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'Mã QR soát vé đã được lưu vào mục "Vé của tôi". Khi đến sự kiện, bạn chỉ cần xuất trình mã QR tại cổng để vào check-in.',
                                style: TextStyle(
                                  color: Color(0xFFB0CADD),
                                  fontSize: 12.5,
                                  height: 1.4,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),

              // Bottom Actions
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                decoration: BoxDecoration(
                  color: const Color(0xFF0C142A),
                  border: Border(top: BorderSide(color: Colors.white.withValues(alpha: 0.08))),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // View Tickets Button
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.pushAndRemoveUntil(
                            context,
                            MaterialPageRoute(builder: (_) => const MyTicketsPage()),
                            (route) => route.isFirst,
                          );
                        },
                        icon: const Icon(Icons.confirmation_number_rounded, color: Color(0xFF070D1E)),
                        label: const Text(
                          'Xem Vé Của Tôi',
                          style: TextStyle(
                            color: Color(0xFF070D1E),
                            fontWeight: FontWeight.w900,
                            fontSize: 15,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFE6C17A),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          elevation: 4,
                        ),
                      ),
                    ),

                    const SizedBox(height: 10),

                    // Back to Home Button
                    SizedBox(
                      width: double.infinity,
                      height: 46,
                      child: OutlinedButton(
                        onPressed: () {
                          Navigator.of(context).popUntil((route) => route.isFirst);
                        },
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: Colors.white.withValues(alpha: 0.2)),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                        child: const Text(
                          'Về Trang Chủ',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(
    String label,
    String value, {
    bool isMonospace = false,
    bool isHighlight = false,
    bool isBold = false,
    Color? valueColor,
    Color? badgeColor,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(color: Color(0xFF8B9CB5), fontSize: 13),
        ),
        if (badgeColor != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: badgeColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: badgeColor.withValues(alpha: 0.4)),
            ),
            child: Text(
              value,
              style: TextStyle(
                color: badgeColor,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
          )
        else
          Text(
            value,
            style: TextStyle(
              color: valueColor ?? (isHighlight ? const Color(0xFFE6C17A) : Colors.white),
              fontSize: isHighlight ? 14 : 13,
              fontWeight: isBold || isHighlight ? FontWeight.bold : FontWeight.w500,
              fontFamily: isMonospace ? 'monospace' : null,
            ),
          ),
      ],
    );
  }
}
