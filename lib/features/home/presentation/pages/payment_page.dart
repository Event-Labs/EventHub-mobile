import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/api/orders_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../tickets/presentation/pages/my_tickets_page.dart';

class PaymentPage extends StatefulWidget {
  final String orderId;
  final Map<String, dynamic>? initialData;

  const PaymentPage({
    super.key,
    required this.orderId,
    this.initialData,
  });

  /// Helper converting PayOS VietQR text/url to a scannable QR image url (identical to Web)
  static String paymentQrImageSrc(String? qrCode) {
    if (qrCode == null || qrCode.trim().isEmpty) return '';
    final trimmed = qrCode.trim();
    if (trimmed.startsWith('http://') || trimmed.startsWith('https://') || trimmed.startsWith('data:image/')) {
      return trimmed;
    }
    return 'https://api.qrserver.com/v1/create-qr-code/?size=250x250&margin=12&data=${Uri.encodeComponent(trimmed)}';
  }

  @override
  State<PaymentPage> createState() => _PaymentPageState();
}

class _PaymentPageState extends State<PaymentPage> {
  Map<String, dynamic>? _orderData;
  Timer? _pollingTimer;
  Timer? _countdownTimer;
  int _secondsLeft = 900; // 15 mins default
  bool _isChecking = false;
  bool _isCancelling = false;
  bool _hasNavigated = false;

  @override
  void initState() {
    super.initState();
    _orderData = widget.initialData;
    _parseExpiredTime();
    _startCountdown();
    _startPolling();
    // Fetch immediately to ensure freshest database state
    _checkStatus(silent: true);
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    _countdownTimer?.cancel();
    super.dispose();
  }

  String get _orderStatus {
    return _orderData?['order']?['status']?.toString().toUpperCase() ?? 'PENDING';
  }

  String get _paymentStatus {
    return _orderData?['payment']?['status']?.toString().toUpperCase() ?? 'PENDING';
  }

  bool get _isExpired {
    return _secondsLeft <= 0 || ['EXPIRED', 'CANCELLED', 'FAILED'].contains(_orderStatus);
  }

  void _parseExpiredTime() {
    final expiredAtStr = _orderData?['order']?['expired_at']?.toString();
    if (expiredAtStr != null && expiredAtStr.isNotEmpty) {
      try {
        final expiredDate = DateTime.parse(expiredAtStr).toUtc();
        final now = DateTime.now().toUtc();
        final diff = expiredDate.difference(now).inSeconds;
        _secondsLeft = diff > 0 ? diff : 0;
      } catch (_) {}
    }
  }

  void _startCountdown() {
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_secondsLeft > 0) {
        setState(() => _secondsLeft--);
      } else {
        timer.cancel();
        _pollingTimer?.cancel();
        if (mounted) setState(() {});
      }
    });
  }

  void _startPolling() {
    _pollingTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (!_isExpired && _orderStatus == 'PENDING') {
        _checkStatus(silent: true);
      }
    });
  }

  Future<void> _checkStatus({bool silent = false}) async {
    if (!silent) setState(() => _isChecking = true);
    final res = await OrdersService().getOrderStatus(widget.orderId);
    if (!silent && mounted) setState(() => _isChecking = false);

    if (res['success'] == true && mounted) {
      final data = res['data'];
      setState(() {
        _orderData = data;
        _parseExpiredTime();
      });
      final status = _orderStatus;

      if (status == 'PAID') {
        _navigateToMyTickets();
      } else if (status == 'CANCELLED' || status == 'EXPIRED') {
        _pollingTimer?.cancel();
        _countdownTimer?.cancel();
      }
    }
  }

  void _navigateToMyTickets() {
    if (_hasNavigated || !mounted) return;
    _hasNavigated = true;
    _pollingTimer?.cancel();
    _countdownTimer?.cancel();

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Thanh toán thành công. Vé của bạn đã sẵn sàng!'),
        backgroundColor: Color(0xFF22C55E),
        duration: Duration(seconds: 3),
      ),
    );

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const MyTicketsPage()),
      (route) => route.isFirst,
    );
  }

  Future<void> _handleCancel() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF101932),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Hủy Đơn Hàng', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: const Text(
          'Bạn có chắc chắn muốn hủy đơn đặt vé này không? Vé đang giữ sẽ được giải phóng cho người khác.',
          style: TextStyle(color: Color(0xFFB0CADD)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Không', style: TextStyle(color: Colors.white70)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Hủy Đơn', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      setState(() => _isCancelling = true);
      final res = await OrdersService().cancelOrder(widget.orderId);
      if (mounted) {
        setState(() => _isCancelling = false);
        if (res['success'] == true) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Đã hủy đơn hàng thành công.')),
          );
          Navigator.pop(context);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(res['message'] ?? 'Không thể hủy đơn hàng.'),
              backgroundColor: AppColors.error,
            ),
          );
        }
      }
    }
  }

  String _formatTimer(int totalSeconds) {
    final m = totalSeconds ~/ 60;
    final s = totalSeconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  static String paymentQrImageSrc(String? qrCode) => PaymentPage.paymentQrImageSrc(qrCode);

  Future<void> _openPayosCheckout(String checkoutUrl) async {
    final uri = Uri.tryParse(checkoutUrl);
    if (uri != null) {
      try {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } catch (_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Không thể mở trang thanh toán PayOS trên trình duyệt.')),
          );
        }
      }
    }
  }

  Widget _buildQrWidget(String? qrCode) {
    if (qrCode != null && qrCode.trim().isNotEmpty) {
      final imageSrc = paymentQrImageSrc(qrCode);
      return Image.network(
        imageSrc,
        width: 220,
        height: 220,
        fit: BoxFit.contain,
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return const SizedBox(
            width: 220,
            height: 220,
            child: Center(
              child: CircularProgressIndicator(strokeWidth: 2.5, color: Color(0xFF60A5FA)),
            ),
          );
        },
        errorBuilder: (context, error, stackTrace) {
          // Fallback to local QrImageView if image API is unreachable
          return QrImageView(
            data: qrCode,
            version: QrVersions.auto,
            size: 220,
            backgroundColor: Colors.white,
          );
        },
      );
    }

    return Container(
      width: 220,
      height: 220,
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white12, style: BorderStyle.solid),
      ),
      child: const Center(
        child: Padding(
          padding: EdgeInsets.all(16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF60A5FA)),
              SizedBox(height: 12),
              Text(
                'QR sẽ hiển thị sau khi PayOS trả dữ liệu.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white60, fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final order = _orderData?['order'] ?? {};
    final payment = _orderData?['payment'] ?? {};
    final event = order['event'] ?? {};
    final eventTitle = event['title']?.toString() ?? 'Sự Kiện EventHub';

    final qrCode = payment['qr_code']?.toString();
    final checkoutUrl = payment['checkout_url']?.toString();

    final totalAmount = order['total_amount'] != null
        ? NumberFormat.currency(locale: 'vi_VN', symbol: 'đ', decimalDigits: 0).format(order['total_amount'])
        : '0 đ';
    final orderCode = order['order_code']?.toString() ?? widget.orderId.substring(0, 8);

    final isExpired = _isExpired;

    return Scaffold(
      backgroundColor: const Color(0xFF070D1E),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0C1446),
        elevation: 0,
        title: const Text(
          'Thanh Toán Đơn Hàng',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.close, color: Colors.white70),
            onPressed: isExpired ? () => Navigator.pop(context) : _handleCancel,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
        child: Column(
          children: [
            // Event title & Subtitle
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
              decoration: BoxDecoration(
                color: const Color(0xFF101932),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFF3B82F6).withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: const Color(0xFF3B82F6).withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFF3B82F6).withOpacity(0.4)),
                    ),
                    child: const Icon(Icons.schedule, color: Color(0xFF60A5FA), size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'PAYOS CHECKOUT',
                          style: TextStyle(
                            color: Color(0xFF60A5FA),
                            fontWeight: FontWeight.w900,
                            fontSize: 11,
                            letterSpacing: 1.2,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          eventTitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Countdown timer box (matching Web: Thời gian giữ vé)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
              decoration: BoxDecoration(
                color: isExpired
                    ? const Color(0xFFEF4444).withOpacity(0.15)
                    : const Color(0xFF101932),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isExpired
                      ? const Color(0xFFEF4444).withOpacity(0.5)
                      : const Color(0xFFE6C17A).withOpacity(0.4),
                ),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.timer_outlined,
                        color: isExpired ? const Color(0xFFEF4444) : const Color(0xFFE6C17A),
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        isExpired ? 'HẾT THỜI GIAN GIỮ VÉ' : 'Thời gian giữ vé còn lại:',
                        style: TextStyle(
                          color: isExpired ? const Color(0xFFEF4444) : const Color(0xFFE6C17A),
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _formatTimer(_secondsLeft),
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 32,
                      fontWeight: FontWeight.w900,
                      color: isExpired ? const Color(0xFFEF4444) : Colors.white,
                      letterSpacing: 2,
                    ),
                  ),
                ],
              ),
            ),

            // Expired Alert Banner (matching Web)
            if (isExpired) ...[
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFEF4444).withOpacity(0.12),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFEF4444).withOpacity(0.4)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.error_outline, color: Color(0xFFEF4444), size: 22),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Giao dịch đã hết thời gian giữ vé hoặc đã bị hủy. Vui lòng đặt vé lại từ đầu.',
                        style: TextStyle(color: Color(0xFFEF4444), fontSize: 13, fontWeight: FontWeight.w500),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 20),

            // Main PayOS QR Card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                color: const Color(0xFF101932),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: Colors.white.withOpacity(0.1)),
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.4), blurRadius: 24, offset: const Offset(0, 10)),
                ],
              ),
              child: Column(
                children: [
                  const Text(
                    'SỐ TIỀN CẦN THANH TOÁN',
                    style: TextStyle(
                      color: Color(0xFF94A3B8),
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    totalAmount,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 34,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.5,
                    ),
                  ),

                  const SizedBox(height: 20),

                  // QR Code Box (VietQR standard via QR Server image / fallback QrImageView)
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 16,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: _buildQrWidget(qrCode),
                  ),

                  const SizedBox(height: 18),

                  const Text(
                    'Quét mã QR bằng ứng dụng Ngân hàng hoặc ví điện tử bất kỳ. Hệ thống sẽ tự động cập nhật khi thanh toán thành công.',
                    style: TextStyle(color: Color(0xFFB0CADD), fontSize: 12, height: 1.4),
                    textAlign: TextAlign.center,
                  ),

                  // Open PayOS checkout web button (matching Web ExternalLink)
                  if (checkoutUrl != null && checkoutUrl.isNotEmpty && !isExpired) ...[
                    const SizedBox(height: 18),
                    ElevatedButton.icon(
                      onPressed: () => _openPayosCheckout(checkoutUrl),
                      icon: const Icon(Icons.open_in_new, size: 18, color: Colors.white),
                      label: const Text(
                        'Mở trang thanh toán PayOS',
                        style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2563EB),
                        minimumSize: const Size(double.infinity, 46),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Order & Payment Details Summary (matching Web aside)
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: const Color(0xFF101932),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: Colors.white10),
              ),
              child: Column(
                children: [
                  _buildDetailRow('Mã đơn hàng', orderCode, isMonospace: true),
                  const Divider(color: Colors.white10, height: 20),
                  _buildDetailRow(
                    'Trạng thái đơn',
                    _orderStatus == 'PAID'
                        ? 'Đã thanh toán'
                        : _orderStatus == 'PENDING'
                            ? 'Chờ thanh toán'
                            : _orderStatus == 'EXPIRED'
                                ? 'Đã hết hạn'
                                : _orderStatus == 'CANCELLED'
                                    ? 'Đã hủy'
                                    : _orderStatus,
                    statusTone: _orderStatus,
                  ),
                  const Divider(color: Colors.white10, height: 20),
                  _buildDetailRow(
                    'Trạng thái PayOS',
                    _paymentStatus,
                    statusTone: _paymentStatus,
                  ),
                  const Divider(color: Colors.white10, height: 20),
                  _buildDetailRow('Tổng tiền', totalAmount, isHighlight: true),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Primary Check Status Button
            if (!isExpired) ...[
              ElevatedButton.icon(
                onPressed: _isChecking ? null : () => _checkStatus(silent: false),
                icon: _isChecking
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.refresh, color: Colors.white),
                label: Text(
                  _isChecking ? 'Đang kiểm tra...' : 'Kiểm tra trạng thái',
                  style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryContainer,
                  minimumSize: const Size(double.infinity, 50),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: (_isCancelling || _orderStatus != 'PENDING') ? null : _handleCancel,
                icon: const Icon(Icons.cancel_outlined, size: 18),
                label: Text(_isCancelling ? 'Đang hủy...' : 'Hủy đơn hàng'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFFEF4444),
                  side: BorderSide(color: const Color(0xFFEF4444).withOpacity(0.4)),
                  minimumSize: const Size(double.infinity, 46),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
              ),
            ] else ...[
              ElevatedButton.icon(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                label: const Text(
                  'Quay lại đặt vé',
                  style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF3B82F6),
                  minimumSize: const Size(double.infinity, 50),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, {bool isHighlight = false, bool isMonospace = false, String? statusTone}) {
    Color valColor = Colors.white;
    if (isHighlight) {
      valColor = const Color(0xFF60A5FA);
    } else if (statusTone != null) {
      if (statusTone == 'PAID') {
        valColor = const Color(0xFF22C55E);
      } else if (statusTone == 'PENDING') {
        valColor = const Color(0xFFE6C17A);
      } else if (statusTone == 'EXPIRED' || statusTone == 'CANCELLED') {
        valColor = const Color(0xFFEF4444);
      }
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13)),
        Text(
          value,
          style: TextStyle(
            color: valColor,
            fontWeight: FontWeight.bold,
            fontSize: isHighlight ? 16 : 14,
            fontFamily: isMonospace ? 'monospace' : null,
          ),
        ),
      ],
    );
  }
}
