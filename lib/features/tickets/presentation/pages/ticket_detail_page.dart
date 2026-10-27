import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../../../core/api/refunds_service.dart';
import '../../../../core/api/tickets_service.dart';
import '../../../../core/constants/banks.dart';
import '../../../../core/models/ticket_model.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_background.dart';
import '../../../feedback/presentation/pages/feedback_page.dart';

class TicketDetailPage extends StatefulWidget {
  final String ticketId;
  final TicketModel? initialTicket;

  const TicketDetailPage({
    super.key,
    required this.ticketId,
    this.initialTicket,
  });

  @override
  State<TicketDetailPage> createState() => _TicketDetailPageState();
}

class _TicketDetailPageState extends State<TicketDetailPage> {
  final GlobalKey _ticketRepaintKey = GlobalKey();
  TicketModel? _ticket;
  bool _isLoading = false;
  bool _isDownloading = false;

  @override
  void initState() {
    super.initState();
    _ticket = widget.initialTicket;
    if (_ticket == null) {
      _loadTicket();
    }
  }

  Future<void> _loadTicket() async {
    setState(() => _isLoading = true);
    final detail = await TicketsService().getTicketDetail(widget.ticketId);
    if (mounted) {
      setState(() {
        _ticket = detail;
        _isLoading = false;
      });
    }
  }

  void _copyToClipboard(String text) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Đã sao chép mã vé vào bộ nhớ tạm'),
        duration: Duration(seconds: 1),
        backgroundColor: Colors.black87,
      ),
    );
  }

  Future<Directory> _getStorageDirectory() async {
    if (Platform.isAndroid) {
      final downloadDir = Directory('/storage/emulated/0/Download');
      if (await downloadDir.exists()) return downloadDir;
      final picturesDir = Directory('/storage/emulated/0/Pictures');
      if (await picturesDir.exists()) return picturesDir;
    }
    return Directory.systemTemp;
  }

  Future<void> _handleDownloadPng() async {
    final ticket = _ticket;
    if (ticket == null) return;

    setState(() => _isDownloading = true);
    try {
      final boundary = _ticketRepaintKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) {
        throw Exception('Không thể kết xuất hình ảnh vé');
      }

      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) {
        throw Exception('Lỗi chuyển đổi dữ liệu hình ảnh');
      }

      final bytes = byteData.buffer.asUint8List();
      final dir = await _getStorageDirectory();
      final filePath = '${dir.path}/EventHub_Ticket_${ticket.ticketCode}.png';
      final file = File(filePath);
      await file.writeAsBytes(bytes);

      if (mounted) {
        _showDownloadSuccessDialog(
          title: 'Đã Lưu Ảnh Vé Vào Thiết Bị!',
          filePath: filePath,
          isImage: true,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi tải vé: $e'), backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _isDownloading = false);
    }
  }

  Future<void> _handleDownloadSvg() async {
    final ticket = _ticket;
    if (ticket == null) return;

    setState(() => _isDownloading = true);
    try {
      final res = await TicketsService().downloadTicketSvg(ticket.ticketId);
      if (res['success'] == true && res['bytes'] != null) {
        final dir = await _getStorageDirectory();
        final filePath = '${dir.path}/EventHub_Ticket_${ticket.ticketCode}.svg';
        final file = File(filePath);
        await file.writeAsBytes(res['bytes'] as List<int>);

        if (mounted) {
          _showDownloadSuccessDialog(
            title: 'Đã Tải Vé SVG Vector Thành Công!',
            filePath: filePath,
            isImage: false,
          );
        }
      } else {
        throw Exception(res['message'] ?? 'Không thể tải tệp SVG từ máy chủ');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi tải vé SVG: $e'), backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _isDownloading = false);
    }
  }

  void _showDownloadChoiceModal() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: Color(0xFF0F1A38),
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Tải Vé Về Thiết Bị',
              style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            const Text(
              'Chọn định dạng bạn muốn lưu trữ để sử dụng khi đến sự kiện:',
              style: TextStyle(color: Color(0xFFB0CADD), fontSize: 13),
            ),
            const SizedBox(height: 20),

            // Option 1: PNG Image (Ready to show at gate)
            ListTile(
              onTap: () {
                Navigator.pop(ctx);
                _handleDownloadPng();
              },
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              tileColor: const Color(0xFF16254F),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFF06B6D4).withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.image, color: Color(0xFF06B6D4), size: 22),
              ),
              title: const Text('Lưu Ảnh Vé (PNG Độ Phân Giải Cao)', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
              subtitle: const Text('Kèm mã QR sắc nét, tiện xuất trình tại cổng không cần mạng', style: TextStyle(color: Color(0xFF8B9CB5), fontSize: 12)),
              trailing: const Icon(Icons.chevron_right, color: Colors.white38),
            ),

            const SizedBox(height: 12),

            // Option 2: SVG Vector official
            ListTile(
              onTap: () {
                Navigator.pop(ctx);
                _handleDownloadSvg();
              },
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              tileColor: const Color(0xFF16254F),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFE6C17A).withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.picture_as_pdf, color: Color(0xFFE6C17A), size: 22),
              ),
              title: const Text('Tải Tệp Vé Chính Thức (SVG Vector)', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
              subtitle: const Text('Bản vẽ chuẩn hệ thống EventHub có thể in ấn hoặc chia sẻ', style: TextStyle(color: Color(0xFF8B9CB5), fontSize: 12)),
              trailing: const Icon(Icons.chevron_right, color: Colors.white38),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  void _showDownloadSuccessDialog({
    required String title,
    required String filePath,
    required bool isImage,
  }) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF101932),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Column(
          children: [
            const Icon(Icons.check_circle, color: Color(0xFF22C55E), size: 52),
            const SizedBox(height: 12),
            Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16), textAlign: TextAlign.center),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Tệp vé đã được lưu an toàn tại:',
              style: TextStyle(color: Color(0xFFB0CADD), fontSize: 13),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFF070D1E),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.white12),
              ),
              child: SelectableText(
                filePath,
                style: const TextStyle(color: Color(0xFFE6C17A), fontSize: 12, fontFamily: 'monospace'),
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              '💡 Mẹo: Bạn có thể mở thư mục Download trên điện thoại để xem và mang theo khi check-in sự kiện.',
              style: TextStyle(color: Color(0xFF8B9CB5), fontSize: 12),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryContainer,
              minimumSize: const Size(double.infinity, 44),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            child: const Text('Đã hiểu', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showReminderModal(TicketModel ticket) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: Color(0xFF0F1A38),
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(width: 44, height: 4, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2))),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF06B6D4).withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.alarm_on, color: Color(0xFF06B6D4), size: 24),
                ),
                const SizedBox(width: 14),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Nhắc Nhở Lịch Sự Kiện', style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold)),
                      Text('Tự động thông báo trước giờ diễn', style: TextStyle(color: Color(0xFF8B9CB5), fontSize: 12)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFF16254F),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white10),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(ticket.eventName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                  const SizedBox(height: 6),
                  Text('⏰ Thời gian: ${ticket.formattedSessionTime}', style: const TextStyle(color: Color(0xFFE6C17A), fontSize: 13)),
                  const SizedBox(height: 4),
                  Text('📍 Địa điểm: ${ticket.venue?.summary ?? "Tại sự kiện"}', style: const TextStyle(color: Color(0xFFB0CADD), fontSize: 12)),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Hệ thống EventHub sẽ tự động gửi email và thông báo đẩy tới điện thoại của bạn trước 24 giờ và 2 giờ để bạn luôn chủ động sắp xếp thời gian!',
              style: TextStyle(color: Color(0xFFB0CADD), fontSize: 13, height: 1.4),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Đã bật tính năng nhận nhắc nhở sự kiện qua thông báo & email!'),
                    backgroundColor: Color(0xFF22C55E),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryContainer,
                minimumSize: const Size(double.infinity, 48),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              child: const Text('Xác Nhận Đặt Nhắc Nhở', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _showRefundModal(TicketModel ticket) {
    final noteController = TextEditingController();
    final accountController = TextEditingController();
    final accountNameController = TextEditingController();

    String selectedReason = 'Trùng lịch cá nhân';
    BankItem? selectedBank;
    bool isSubmitting = false;
    bool previewLoading = true;
    Map<String, dynamic>? previewData;
    String? previewError;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          // Initialize preview on first render
          if (previewLoading && previewData == null && previewError == null) {
            RefundsService().getRefundPreview(ticketId: ticket.ticketId).then((res) {
              if (ctx.mounted) {
                setModalState(() {
                  previewLoading = false;
                  if (res['success'] == true && res['data'] != null) {
                    previewData = res['data'] as Map<String, dynamic>;
                  } else {
                    previewError = res['message']?.toString() ?? 'Không thể lấy thông tin tính toán hoàn tiền.';
                  }
                });
              }
            }).catchError((err) {
              if (ctx.mounted) {
                setModalState(() {
                  previewLoading = false;
                  previewError = 'Không thể kiểm tra chính sách hoàn tiền.';
                });
              }
            });
          }

          final originalPrice = ticket.originalPrice ?? ticket.price ?? 0.0;
          final actualPaid = (previewData != null && previewData!['paid_amount'] != null)
              ? (double.tryParse(previewData!['paid_amount'].toString()) ?? ticket.price ?? originalPrice)
              : (ticket.price ?? originalPrice);
          final discountAmount = originalPrice > actualPaid ? originalPrice - actualPaid : 0.0;
          final isEligible = previewData == null || previewData!['eligible'] == true;
          final currencyFormat = NumberFormat.currency(locale: 'vi_VN', symbol: 'đ', decimalDigits: 0);

          return Container(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.9,
            ),
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom,
            ),
            decoration: const BoxDecoration(
              color: Color(0xFF0F172A),
              borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
              border: Border(top: BorderSide(color: Colors.white12)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Top drag handle
                const SizedBox(height: 12),
                Center(
                  child: Container(
                    width: 44,
                    height: 4,
                    decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)),
                  ),
                ),

                // Header
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 14, 16, 12),
                  child: Row(
                    children: [
                      Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: const Color(0xFFC99A47).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFE6C17A).withValues(alpha: 0.3)),
                        ),
                        child: const Icon(Icons.rotate_left, color: Color(0xFFE6C17A), size: 20),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Yêu cầu hoàn tiền vé',
                              style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'Xem trước thông tin hoàn tiền & gửi yêu cầu đến BTC',
                              style: TextStyle(color: Color(0xFF8B9CB5), fontSize: 11),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white70, size: 20),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                ),
                const Divider(color: Colors.white10, height: 1),

                // Scrollable content
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // 1. Ticket Summary Card (matching Web)
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.03),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Text(
                                          'SỰ KIỆN',
                                          style: TextStyle(
                                            color: Color(0xFFE6C17A),
                                            fontSize: 10,
                                            fontWeight: FontWeight.w900,
                                            letterSpacing: 1.1,
                                          ),
                                        ),
                                        const SizedBox(height: 3),
                                        Text(
                                          ticket.eventName,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 13,
                                            fontWeight: FontWeight.bold,
                                          ),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF06B6D4).withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(color: const Color(0xFF06B6D4).withValues(alpha: 0.3)),
                                    ),
                                    child: Text(
                                      ticket.ticketCode,
                                      style: const TextStyle(
                                        color: Color(0xFF06B6D4),
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              Padding(
                                padding: const EdgeInsets.symmetric(vertical: 10),
                                child: Divider(color: Colors.white.withValues(alpha: 0.08), height: 1),
                              ),
                              Row(
                                children: [
                                  Expanded(
                                    child: _buildTicketInfoRow('Hạng vé:', ticket.ticketType ?? 'Vé tiêu chuẩn'),
                                  ),
                                  Expanded(
                                    child: _buildTicketInfoRow(
                                      'Mã đơn:',
                                      '#${ticket.orderCode ?? (ticket.ticketId.length >= 8 ? ticket.ticketId.substring(0, 8) : ticket.ticketId)}',
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Expanded(
                                    child: _buildTicketInfoRow('Giá gốc:', currencyFormat.format(originalPrice)),
                                  ),
                                  if (discountAmount > 0)
                                    Expanded(
                                      child: _buildTicketInfoRow(
                                        'Khuyến mãi:',
                                        '-${currencyFormat.format(discountAmount)}',
                                        valueColor: const Color(0xFF34D399),
                                      ),
                                    )
                                  else
                                    Expanded(
                                      child: _buildTicketInfoRow(
                                        'Thực tế đã trả:',
                                        currencyFormat.format(actualPaid),
                                        valueColor: const Color(0xFFE6C17A),
                                      ),
                                    ),
                                ],
                              ),
                              if (discountAmount > 0) ...[
                                const SizedBox(height: 8),
                                _buildTicketInfoRow(
                                  'Thực tế đã trả:',
                                  currencyFormat.format(actualPaid),
                                  valueColor: const Color(0xFFE6C17A),
                                ),
                              ],
                              if (ticket.sessionTime != null && ticket.sessionTime!.isNotEmpty) ...[
                                const SizedBox(height: 8),
                                _buildTicketInfoRow('Thời gian:', ticket.sessionTime!),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),

                        // 2. Refund Preview State / Loading / Calculated Result
                        if (previewLoading)
                          Container(
                            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 14),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.02),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                            ),
                            child: const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFFE6C17A)),
                                ),
                                SizedBox(width: 12),
                                Flexible(
                                  child: Text(
                                    'Đang kiểm tra chính sách và tính toán số tiền hoàn...',
                                    style: TextStyle(color: Color(0xFF8B9CB5), fontSize: 12),
                                  ),
                                ),
                              ],
                            ),
                          )
                        else if (previewError != null)
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF43F5E).withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: const Color(0xFFF43F5E).withValues(alpha: 0.3)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Không thể tải thông tin xem trước:',
                                  style: TextStyle(color: Color(0xFFFDA4AF), fontWeight: FontWeight.bold, fontSize: 12),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  previewError!,
                                  style: const TextStyle(color: Color(0xFFFECDD3), fontSize: 11),
                                ),
                              ],
                            ),
                          )
                        else if (previewData != null) ...[
                          // Days before & Refund Rate
                          Row(
                            children: [
                              Expanded(
                                child: Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.02),
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text('Thời gian trước sự kiện', style: TextStyle(color: Color(0xFF8B9CB5), fontSize: 11)),
                                      const SizedBox(height: 4),
                                      Text(
                                        previewData!['days_before_event'] != null
                                            ? '${previewData!['days_before_event']} ngày'
                                            : 'N/A',
                                        style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.02),
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text('Tỷ lệ hoàn áp dụng', style: TextStyle(color: Color(0xFF8B9CB5), fontSize: 11)),
                                      const SizedBox(height: 4),
                                      Text(
                                        '${previewData!['refund_rate'] ?? 0}%',
                                        style: const TextStyle(color: Color(0xFF34D399), fontSize: 14, fontWeight: FontWeight.bold),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),

                          // Proposed Refund Amount Highlight
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            decoration: BoxDecoration(
                              color: const Color(0xFF10B981).withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.35)),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  'Số tiền hoàn đề xuất:',
                                  style: TextStyle(color: Color(0xFF6EE7B7), fontWeight: FontWeight.bold, fontSize: 13),
                                ),
                                Text(
                                  currencyFormat.format(previewData!['refund_amount'] ?? 0),
                                  style: const TextStyle(
                                    color: Color(0xFF34D399),
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                              ],
                            ),
                          ),

                          // Ineligible Notice if not eligible
                          if (!isEligible) ...[
                            const SizedBox(height: 10),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF43F5E).withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: const Color(0xFFF43F5E).withValues(alpha: 0.35)),
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Icon(Icons.error_outline, color: Color(0xFFF43F5E), size: 18),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Text(
                                          'Không đủ điều kiện hoàn vé',
                                          style: TextStyle(color: Color(0xFFFDA4AF), fontWeight: FontWeight.bold, fontSize: 12),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          previewData!['reason']?.toString() ?? 'Vé này hiện không đủ điều kiện hoàn vé theo quy định.',
                                          style: const TextStyle(color: Color(0xFFFECDD3), fontSize: 11),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],

                          // Event refund policy text
                          if (previewData!['policy_text'] != null &&
                              previewData!['policy_text'].toString().trim().isNotEmpty) ...[
                            const SizedBox(height: 10),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: const Color(0xFF06B6D4).withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: const Color(0xFF06B6D4).withValues(alpha: 0.25)),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Chính sách hoàn vé của sự kiện:',
                                    style: TextStyle(color: Color(0xFF67E8F9), fontWeight: FontWeight.bold, fontSize: 12),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    previewData!['policy_text'].toString(),
                                    style: const TextStyle(color: Color(0xFFCBD5E1), fontSize: 11, height: 1.35),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                        const SizedBox(height: 16),

                        // 3. Reason Section (Dropdown + Note)
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.25),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Row(
                                children: [
                                  Text('Lý do hoàn vé ', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
                                  Text('*', style: TextStyle(color: Color(0xFFF43F5E), fontSize: 13, fontWeight: FontWeight.bold)),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 14),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF070D1E),
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(color: Colors.white12),
                                ),
                                child: DropdownButtonHideUnderline(
                                  child: DropdownButton<String>(
                                    value: selectedReason,
                                    isExpanded: true,
                                    dropdownColor: const Color(0xFF0F172A),
                                    icon: const Icon(Icons.keyboard_arrow_down, color: Color(0xFFE6C17A)),
                                    style: const TextStyle(color: Color(0xFFF5EBDD), fontSize: 13, fontWeight: FontWeight.w500),
                                    items: const [
                                      DropdownMenuItem(value: 'Trùng lịch cá nhân', child: Text('Trùng lịch cá nhân')),
                                      DropdownMenuItem(value: 'Sự kiện thay đổi thông tin', child: Text('Sự kiện thay đổi thông tin')),
                                      DropdownMenuItem(value: 'Mua nhầm vé', child: Text('Mua nhầm vé')),
                                      DropdownMenuItem(value: 'Lý do sức khỏe', child: Text('Lý do sức khỏe')),
                                      DropdownMenuItem(value: 'Khác', child: Text('Khác')),
                                    ],
                                    onChanged: (val) {
                                      if (val != null) {
                                        setModalState(() => selectedReason = val);
                                      }
                                    },
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  const Text('Ghi chú chi tiết ', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
                                  if (selectedReason == 'Khác')
                                    const Text('*', style: TextStyle(color: Color(0xFFF43F5E), fontSize: 13, fontWeight: FontWeight.bold)),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Container(
                                decoration: BoxDecoration(
                                  color: const Color(0xFF070D1E),
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(color: Colors.white12),
                                ),
                                child: TextField(
                                  controller: noteController,
                                  maxLines: 3,
                                  maxLength: 500,
                                  style: const TextStyle(color: Colors.white, fontSize: 13),
                                  decoration: InputDecoration(
                                    hintText: selectedReason == 'Khác'
                                        ? 'Vui lòng nêu rõ lý do hoàn vé (bắt buộc)...'
                                        : 'Thông tin bổ sung (nếu có, tối đa 500 ký tự)...',
                                    hintStyle: const TextStyle(color: Color(0xFF8B9CB5), fontSize: 12),
                                    border: InputBorder.none,
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                    counterStyle: const TextStyle(color: Colors.white38, fontSize: 10),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),

                        // 4. Bank Information Section
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.02),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Row(
                                children: [
                                  Text(
                                    'Tài khoản ngân hàng nhận tiền hoàn ',
                                    style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                                  ),
                                  Text('*', style: TextStyle(color: Color(0xFFF43F5E), fontSize: 13, fontWeight: FontWeight.bold)),
                                ],
                              ),
                              const SizedBox(height: 10),

                              // Bank Picker Trigger
                              InkWell(
                                onTap: () {
                                  _showBankPickerDialog(context, (bank) {
                                    setModalState(() => selectedBank = bank);
                                  });
                                },
                                borderRadius: BorderRadius.circular(14),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF070D1E),
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(color: Colors.white12),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.account_balance_outlined, color: Color(0xFFE6C17A), size: 18),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Text(
                                          selectedBank != null ? selectedBank!.displayName : '-- Chọn ngân hàng * --',
                                          style: TextStyle(
                                            color: selectedBank != null ? const Color(0xFFF5EBDD) : const Color(0xFF8B9CB5),
                                            fontSize: 13,
                                            fontWeight: selectedBank != null ? FontWeight.w500 : FontWeight.normal,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      const Icon(Icons.keyboard_arrow_down, color: Color(0xFFE6C17A), size: 20),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(height: 10),

                              // Account Number
                              Container(
                                decoration: BoxDecoration(
                                  color: const Color(0xFF070D1E),
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(color: Colors.white12),
                                ),
                                child: TextField(
                                  controller: accountController,
                                  keyboardType: TextInputType.number,
                                  style: const TextStyle(color: Colors.white, fontSize: 13),
                                  decoration: const InputDecoration(
                                    hintText: 'Số tài khoản *',
                                    hintStyle: TextStyle(color: Color(0xFF8B9CB5), fontSize: 12),
                                    border: InputBorder.none,
                                    contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 10),

                              // Account Holder Name
                              Container(
                                decoration: BoxDecoration(
                                  color: const Color(0xFF070D1E),
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(color: Colors.white12),
                                ),
                                child: TextField(
                                  controller: accountNameController,
                                  textCapitalization: TextCapitalization.characters,
                                  inputFormatters: [
                                    TextInputFormatter.withFunction((oldValue, newValue) {
                                      return newValue.copyWith(
                                        text: newValue.text.toUpperCase(),
                                        selection: newValue.selection,
                                      );
                                    }),
                                  ],
                                  style: const TextStyle(color: Colors.white, fontSize: 13),
                                  decoration: const InputDecoration(
                                    hintText: 'Tên chủ tài khoản (viết hoa không dấu) *',
                                    hintStyle: TextStyle(color: Color(0xFF8B9CB5), fontSize: 12),
                                    border: InputBorder.none,
                                    contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),
                      ],
                    ),
                  ),
                ),

                // Footer Buttons (matching Web)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                  decoration: const BoxDecoration(
                    color: Color(0xFF0A1124),
                    border: Border(top: BorderSide(color: Colors.white10)),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(ctx),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Colors.white24),
                            minimumSize: const Size(0, 46),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                          ),
                          child: const Text('Hủy', style: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold)),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: ElevatedButton(
                          onPressed: (isSubmitting || previewLoading || !isEligible)
                              ? null
                              : () async {
                                  if (selectedBank == null) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('Vui lòng chọn ngân hàng nhận tiền hoàn'),
                                        backgroundColor: AppColors.error,
                                      ),
                                    );
                                    return;
                                  }

                                  final acc = accountController.text.trim();
                                  final accName = accountNameController.text.trim();
                                  final note = noteController.text.trim();

                                  if (acc.isEmpty || accName.isEmpty) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('Vui lòng nhập đầy đủ số tài khoản và tên chủ tài khoản'),
                                        backgroundColor: AppColors.error,
                                      ),
                                    );
                                    return;
                                  }

                                  if (selectedReason == 'Khác' && note.isEmpty) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('Vui lòng nhập ghi chú chi tiết khi chọn lý do "Khác"'),
                                        backgroundColor: AppColors.error,
                                      ),
                                    );
                                    return;
                                  }

                                  final messenger = ScaffoldMessenger.of(context);
                                  setModalState(() => isSubmitting = true);

                                  final res = await RefundsService().submitRefundRequest(
                                    ticketId: ticket.ticketId,
                                    reason: selectedReason,
                                    customerNote: note,
                                    bankName: selectedBank!.displayName,
                                    bankAccountNumber: acc,
                                    bankAccountName: accName.toUpperCase(),
                                  );

                                  setModalState(() => isSubmitting = false);

                                  messenger.showSnackBar(
                                    SnackBar(
                                      content: Text(res['message'] ?? 'Đã gửi yêu cầu hoàn vé'),
                                      backgroundColor: res['success'] == true ? const Color(0xFF22C55E) : AppColors.error,
                                      duration: const Duration(seconds: 4),
                                    ),
                                  );

                                  if (ctx.mounted) {
                                    Navigator.pop(ctx);
                                  }
                                  if (mounted) {
                                    _loadTicket();
                                  }
                                },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFE6C17A),
                            disabledBackgroundColor: Colors.white12,
                            minimumSize: const Size(0, 46),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                            elevation: 0,
                          ),
                          child: isSubmitting
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF070D1E)),
                                )
                              : Text(
                                  isSubmitting ? 'Đang gửi...' : 'Gửi yêu cầu',
                                  style: TextStyle(
                                    color: (isSubmitting || previewLoading || !isEligible)
                                        ? Colors.white38
                                        : const Color(0xFF070D1E),
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildTicketInfoRow(String label, String value, {Color? valueColor}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Color(0xFF8B9CB5), fontSize: 11)),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            color: valueColor ?? Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  void _showBankPickerDialog(BuildContext context, ValueChanged<BankItem> onSelected) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        String search = '';
        return StatefulBuilder(
          builder: (context, setPickerState) {
            final filtered = vietnameseBanks.where((b) {
              final q = search.toLowerCase().trim();
              if (q.isEmpty) return true;
              return b.shortName.toLowerCase().contains(q) ||
                  b.code.toLowerCase().contains(q) ||
                  b.fullName.toLowerCase().contains(q);
            }).toList();

            return Container(
              height: MediaQuery.of(context).size.height * 0.75,
              decoration: const BoxDecoration(
                color: Color(0xFF0F172A),
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                border: Border(top: BorderSide(color: Colors.white12)),
              ),
              child: Column(
                children: [
                  const SizedBox(height: 12),
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Chọn ngân hàng thụ hưởng',
                          style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, color: Colors.white70, size: 20),
                          onPressed: () => Navigator.pop(ctx),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                    child: Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFF16254F),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.white12),
                      ),
                      child: TextField(
                        autofocus: false,
                        style: const TextStyle(color: Colors.white, fontSize: 13),
                        decoration: const InputDecoration(
                          hintText: 'Tìm kiếm ngân hàng (VCB, MB, Techcombank...)',
                          hintStyle: TextStyle(color: Color(0xFF8B9CB5), fontSize: 12),
                          prefixIcon: Icon(Icons.search, color: Color(0xFF8B9CB5), size: 18),
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        ),
                        onChanged: (val) => setPickerState(() => search = val),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      itemCount: filtered.length,
                      separatorBuilder: (_, __) => const Divider(color: Colors.white10, height: 1),
                      itemBuilder: (context, index) {
                        final bank = filtered[index];
                        return ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          title: Text(
                            bank.shortName,
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                          subtitle: Text(
                            '${bank.code} - ${bank.fullName}',
                            style: const TextStyle(color: Color(0xFF8B9CB5), fontSize: 11),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          trailing: const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white24, size: 13),
                          onTap: () {
                            onSelected(bank);
                            Navigator.pop(ctx);
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading && _ticket == null) {
      return const AppBackground(
        child: Scaffold(
          backgroundColor: Colors.transparent,
          body: Center(child: CircularProgressIndicator(color: AppColors.primaryContainer)),
        ),
      );
    }

    final ticket = _ticket;
    if (ticket == null) {
      return AppBackground(
        child: Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(backgroundColor: Colors.transparent, elevation: 0),
          body: const Center(
            child: Text('Không tìm thấy thông tin vé.', style: TextStyle(color: Colors.white70)),
          ),
        ),
      );
    }

    final statusColor = ticket.statusColor;

    return AppBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          title: const Text('Chi Tiết Vé Điện Tử', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            onPressed: () => _showReminderModal(ticket),
            icon: const Icon(Icons.alarm_add, color: Color(0xFFE6C17A)),
            tooltip: 'Đặt nhắc nhở',
          ),
          IconButton(
            onPressed: _isDownloading ? null : _showDownloadChoiceModal,
            icon: _isDownloading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.download, color: Colors.white),
            tooltip: 'Tải vé về máy',
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // RepaintBoundary wrapping the Ticket Card for PNG capture
            RepaintBoundary(
              key: _ticketRepaintKey,
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF101932),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.5),
                      blurRadius: 24,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                clipBehavior: Clip.antiAlias,
                child: Column(
                  children: [
                    // Event Header & Banner
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Color(0xFF1A284D),
                            Color(0xFF101932),
                          ],
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: statusColor.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: statusColor.withValues(alpha: 0.5)),
                                ),
                                child: Text(
                                  ticket.formattedStatus.toUpperCase(),
                                  style: TextStyle(color: statusColor, fontSize: 11, fontWeight: FontWeight.bold),
                                ),
                              ),
                              Text(
                                ticket.formattedPrice,
                                style: const TextStyle(color: Color(0xFFE6C17A), fontSize: 17, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            ticket.eventName,
                            style: const TextStyle(color: Colors.white, fontSize: 19, fontWeight: FontWeight.bold, height: 1.3),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            '${ticket.ticketType ?? "Vé tham dự"} • ${ticket.seatName ?? "GA"}',
                            style: const TextStyle(color: Color(0xFFE6C17A), fontSize: 13, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),

                    // Tear line with cutouts
                    Row(
                      children: [
                        Container(
                          width: 14,
                          height: 28,
                          decoration: const BoxDecoration(
                            color: Color(0xFF070D1E),
                            borderRadius: BorderRadius.horizontal(right: Radius.circular(14)),
                          ),
                        ),
                        Expanded(
                          child: LayoutBuilder(
                            builder: (context, constraints) {
                              return Flex(
                                direction: Axis.horizontal,
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: List.generate(
                                  (constraints.constrainWidth() / 10).floor(),
                                  (_) => const SizedBox(
                                    width: 5,
                                    height: 1.5,
                                    child: DecoratedBox(decoration: BoxDecoration(color: Colors.white12)),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                        Container(
                          width: 14,
                          height: 28,
                          decoration: const BoxDecoration(
                            color: Color(0xFF070D1E),
                            borderRadius: BorderRadius.horizontal(left: Radius.circular(14)),
                          ),
                        ),
                      ],
                    ),

                    // QR Code Section
                    Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.primaryContainer.withValues(alpha: 0.2),
                                  blurRadius: 20,
                                ),
                              ],
                            ),
                            child: QrImageView(
                              data: ticket.qrPayload,
                              version: QrVersions.auto,
                              size: 210,
                            ),
                          ),
                          const SizedBox(height: 16),
                          GestureDetector(
                            onTap: () => _copyToClipboard(ticket.ticketCode),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  ticket.ticketCode,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 2,
                                    fontFamily: 'monospace',
                                  ),
                                ),
                                const SizedBox(width: 8),
                                const Icon(Icons.copy, color: Color(0xFFB0CADD), size: 16),
                              ],
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            ticket.isUsed
                                ? 'Vé đã được xác nhận check-in tại cổng'
                                : 'Xuất trình mã này cho nhân viên soát vé tại sự kiện',
                            style: TextStyle(
                              color: ticket.isUsed ? const Color(0xFF06B6D4) : const Color(0xFF22C55E),
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),

                    // Detailed metadata section
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Column(
                        children: [
                          const Divider(color: Colors.white12, height: 1),
                          const SizedBox(height: 16),
                          _buildInfoTile('Thời gian diễn:', ticket.formattedSessionTime, Icons.access_time),
                          _buildInfoTile('Địa điểm:', ticket.venue?.summary ?? 'TP. Hồ Chí Minh', Icons.location_on),
                          if (ticket.venue?.fullAddress.isNotEmpty == true)
                            _buildInfoTile('Địa chỉ chi tiết:', ticket.venue!.fullAddress, Icons.map),
                          _buildInfoTile('Chỗ ngồi / Khu:', ticket.seatName ?? 'Khu vực tự do (GA)', Icons.event_seat),
                          _buildInfoTile('Người tham dự:', ticket.attendeeName ?? 'Khách hàng', Icons.person),
                          if (ticket.attendeeEmail != null && ticket.attendeeEmail!.isNotEmpty)
                            _buildInfoTile('Email:', ticket.attendeeEmail!, Icons.email),
                          if (ticket.attendeePhone != null && ticket.attendeePhone!.isNotEmpty)
                            _buildInfoTile('Số điện thoại:', ticket.attendeePhone!, Icons.phone),
                          if (ticket.orderCode != null && ticket.orderCode!.isNotEmpty)
                            _buildInfoTile('Mã đơn hàng:', ticket.orderCode!, Icons.receipt_long),
                          if (ticket.checkInTime != null)
                            _buildInfoTile('Giờ check-in:', ticket.formattedCheckInTime, Icons.check_circle_outline),
                          const SizedBox(height: 16),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Action Buttons
            if (ticket.isUsed) ...[
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => FeedbackPage(initialEventId: ticket.eventId),
                    ),
                  );
                },
                icon: const Icon(Icons.star_rate_rounded, color: Color(0xFF070D1E)),
                label: const Text('Đánh Giá Trải Nghiệm Sự Kiện', style: TextStyle(color: Color(0xFF070D1E), fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFE6C17A),
                  minimumSize: const Size(double.infinity, 48),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
              ),
            ],

            if (ticket.isValid && !ticket.isUsed && !ticket.isRefundPending) ...[
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: () => _showRefundModal(ticket),
                icon: const Icon(Icons.replay, color: Color(0xFFE6C17A), size: 18),
                label: const Text('Yêu Cầu Hoàn Vé', style: TextStyle(color: Color(0xFFE6C17A), fontWeight: FontWeight.bold)),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: const Color(0xFFE6C17A).withValues(alpha: 0.5)),
                  minimumSize: const Size(double.infinity, 46),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
              ),
            ],

            const SizedBox(height: 32),
          ],
        ),
      ),
    ),
  );
  }

  Widget _buildInfoTile(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: const Color(0xFFB0CADD), size: 16),
          const SizedBox(width: 10),
          SizedBox(
            width: 120,
            child: Text(label, style: const TextStyle(color: Color(0xFF8B9CB5), fontSize: 13)),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }
}
