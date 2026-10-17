import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart';
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

  @override
  void initState() {
    super.initState();
    _orderData = widget.initialData;
    _parseExpiredTime();
    _startPolling();
    _startCountdown();
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    _countdownTimer?.cancel();
    super.dispose();
  }

  void _parseExpiredTime() {
    final expiredAtStr = _orderData?['order']?['expired_at'];
    if (expiredAtStr != null) {
      try {
        final expiredDate = DateTime.parse(expiredAtStr);
        final diff = expiredDate.difference(DateTime.now()).inSeconds;
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
      }
    });
  }

  void _startPolling() {
    _pollingTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      _checkStatus(silent: true);
    });
  }

  Future<void> _checkStatus({bool silent = false}) async {
    if (!silent) setState(() => _isChecking = true);
    final res = await OrdersService().getOrderStatus(widget.orderId);
    if (!silent) setState(() => _isChecking = false);

    if (res['success'] == true && mounted) {
      final data = res['data'];
      setState(() => _orderData = data);
      final status = data?['order']?['status']?.toString().toUpperCase();

      if (status == 'PAID') {
        _pollingTimer?.cancel();
        _countdownTimer?.cancel();
        _showSuccessDialog();
      } else if (status == 'CANCELLED' || status == 'EXPIRED') {
        _pollingTimer?.cancel();
        _countdownTimer?.cancel();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Đơn hàng đã hết hạn hoặc bị hủy'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _handleCancel() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF101932),
        title: const Text('Hủy Đơn Hàng', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: const Text('Bạn có chắc chắn muốn hủy đơn đặt vé này không?', style: TextStyle(color: Color(0xFFB0CADD))),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Không', style: TextStyle(color: Colors.white70))),
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
      await OrdersService().cancelOrder(widget.orderId);
      if (mounted) {
        Navigator.pop(context);
      }
    }
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF101932),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Column(
          children: [
            Icon(Icons.check_circle, color: Color(0xFF22C55E), size: 68),
            SizedBox(height: 12),
            Text('Thanh Toán Thành Công!', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 20)),
          ],
        ),
        content: const Text(
          'Đơn hàng của bạn đã được PayOS xác nhận thành công. Vé điện tử kèm mã QR đã sẵn sàng trong ví vé của bạn!',
          style: TextStyle(color: Color(0xFFB0CADD), fontSize: 13, height: 1.4),
          textAlign: TextAlign.center,
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (_) => const MyTicketsPage()),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryContainer,
              minimumSize: const Size(double.infinity, 48),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
            child: const Text('Xem Vé Của Tôi', style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  String _formatTimer(int totalSeconds) {
    final m = totalSeconds ~/ 60;
    final s = totalSeconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final order = _orderData?['order'] ?? {};
    final payment = _orderData?['payment'] ?? {};
    final qrData = payment['qr_code']?.toString() ?? payment['checkout_url']?.toString() ?? widget.orderId;
    final totalAmount = order['total_amount'] != null
        ? NumberFormat.currency(locale: 'vi_VN', symbol: 'đ', decimalDigits: 0).format(order['total_amount'])
        : '0 đ';
    final orderCode = order['order_code']?.toString() ?? widget.orderId.substring(0, 8);

    return Scaffold(
      backgroundColor: const Color(0xFF070D1E),
      appBar: AppBar(
        backgroundColor: const Color(0xFF070D1E),
        elevation: 0,
        title: const Text('Thanh Toán PayOS', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.close, color: Colors.white70),
            onPressed: _handleCancel,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // Countdown timer card
            Container(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
              decoration: BoxDecoration(
                color: const Color(0xFF101932),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.amber.withOpacity(0.4)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.timer, color: Color(0xFFE6C17A), size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'Thời gian giữ vé còn lại: ${_formatTimer(_secondsLeft)}',
                    style: const TextStyle(color: Color(0xFFE6C17A), fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Main PayOS QR Card
            Container(
              padding: const EdgeInsets.all(24),
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
                    'Quét mã để thanh toán',
                    style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Mở ứng dụng Ngân hàng hoặc ví điện tử bất kỳ để quét mã VietQR',
                    style: TextStyle(color: Color(0xFFB0CADD), fontSize: 12),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),

                  // QR Code Box
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(color: AppColors.primaryContainer.withOpacity(0.2), blurRadius: 20),
                      ],
                    ),
                    child: qrData.startsWith('http') && qrData.endsWith('.png')
                        ? Image.network(qrData, width: 220, height: 220)
                        : QrImageView(
                            data: qrData,
                            version: QrVersions.auto,
                            size: 220,
                          ),
                  ),

                  const SizedBox(height: 20),

                  // Amount and Order details
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF070D1E),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Số tiền thanh toán:', style: TextStyle(color: Color(0xFFB0CADD), fontSize: 13)),
                            Text(
                              totalAmount,
                              style: const TextStyle(color: Color(0xFFFFB690), fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                        const Divider(color: Colors.white12, height: 20),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Mã đơn hàng:', style: TextStyle(color: Color(0xFFB0CADD), fontSize: 13)),
                            Text(
                              orderCode,
                              style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold, fontFamily: 'monospace'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Status check & buttons
            ElevatedButton.icon(
              onPressed: _isChecking ? null : () => _checkStatus(silent: false),
              icon: _isChecking
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.refresh, color: Colors.white),
              label: Text(
                _isChecking ? 'Đang kiểm tra...' : 'Tôi đã chuyển khoản thành công',
                style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryContainer,
                minimumSize: const Size(double.infinity, 50),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
            ),

            const SizedBox(height: 12),

            OutlinedButton(
              onPressed: _isCancelling ? null : _handleCancel,
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white70,
                side: const BorderSide(color: Colors.white24),
                minimumSize: const Size(double.infinity, 46),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              child: const Text('Hủy giao dịch'),
            ),
          ],
        ),
      ),
    );
  }
}
