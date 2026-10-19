import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../../../core/api/refunds_service.dart';
import '../../../../core/api/tickets_service.dart';
import '../../../../core/models/ticket_model.dart';
import '../../../../core/theme/app_colors.dart';
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
    final reasonController = TextEditingController();
    final bankController = TextEditingController();
    final accountController = TextEditingController();
    final accountNameController = TextEditingController();
    bool isSubmitting = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          return Container(
            padding: EdgeInsets.only(
              top: 24,
              left: 20,
              right: 20,
              bottom: MediaQuery.of(context).viewInsets.bottom + 24,
            ),
            decoration: const BoxDecoration(
              color: Color(0xFF0F1A38),
              borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            ),
            child: SingleChildScrollView(
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
                  const Text('Yêu Cầu Hoàn Vé', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  Text(
                    'Mã vé: ${ticket.ticketCode} (${ticket.ticketType ?? "Vé tham dự"})',
                    style: const TextStyle(color: Color(0xFFB0CADD), fontSize: 13),
                  ),
                  const SizedBox(height: 20),

                  _buildModalTextField('Tên ngân hàng (Vietcombank, MB, Techcombank...)', bankController),
                  const SizedBox(height: 12),
                  _buildModalTextField('Số tài khoản nhận tiền hoàn', accountController, keyboardType: TextInputType.number),
                  const SizedBox(height: 12),
                  _buildModalTextField('Tên chủ tài khoản (viết hoa không dấu)', accountNameController),
                  const SizedBox(height: 12),
                  _buildModalTextField('Lý do yêu cầu hoàn vé', reasonController, maxLines: 3),

                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: isSubmitting
                        ? null
                        : () async {
                            final bank = bankController.text.trim();
                            final acc = accountController.text.trim();
                            final accName = accountNameController.text.trim();
                            final reason = reasonController.text.trim();

                            if (bank.isEmpty || acc.isEmpty || accName.isEmpty || reason.isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Vui lòng điền đầy đủ thông tin hoàn vé'), backgroundColor: AppColors.error),
                              );
                              return;
                            }

                            final messenger = ScaffoldMessenger.of(context);
                            setModalState(() => isSubmitting = true);
                            final res = await RefundsService().submitRefundRequest(
                              ticketId: ticket.ticketId,
                              reason: reason,
                              bankName: bank,
                              bankAccountNumber: acc,
                              bankAccountName: accName,
                            );
                            setModalState(() => isSubmitting = false);

                            messenger.showSnackBar(
                              SnackBar(
                                content: Text(res['message'] ?? 'Đã gửi yêu cầu hoàn vé'),
                                backgroundColor: res['success'] == true ? Colors.green : AppColors.error,
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
                      backgroundColor: AppColors.primaryContainer,
                      minimumSize: const Size(double.infinity, 48),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    child: isSubmitting
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Text('Gửi Yêu Cầu Hoàn Tiền', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildModalTextField(String label, TextEditingController controller, {int maxLines = 1, TextInputType? keyboardType}) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF16254F),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white12),
      ),
      child: TextField(
        controller: controller,
        maxLines: maxLines,
        keyboardType: keyboardType,
        style: const TextStyle(color: Colors.white, fontSize: 13),
        decoration: InputDecoration(
          hintText: label,
          hintStyle: const TextStyle(color: Color(0xFF8B9CB5), fontSize: 12),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading && _ticket == null) {
      return const Scaffold(
        backgroundColor: Color(0xFF070D1E),
        body: Center(child: CircularProgressIndicator(color: AppColors.primaryContainer)),
      );
    }

    final ticket = _ticket;
    if (ticket == null) {
      return Scaffold(
        backgroundColor: const Color(0xFF070D1E),
        appBar: AppBar(backgroundColor: const Color(0xFF070D1E), elevation: 0),
        body: const Center(
          child: Text('Không tìm thấy thông tin vé.', style: TextStyle(color: Colors.white70)),
        ),
      );
    }

    final statusColor = ticket.statusColor;

    return Scaffold(
      backgroundColor: const Color(0xFF070D1E),
      appBar: AppBar(
        backgroundColor: const Color(0xFF070D1E),
        elevation: 0,
        title: const Text('Chi Tiết Vé Điện Tử', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            onPressed: () => _showReminderModal(ticket),
            icon: const Icon(Icons.alarm_add, color: Color(0xFFE6C17A)),
            tooltip: 'Đặt nhắc nhở',
          ),
          IconButton(
            onPressed: _showDownloadChoiceModal,
            icon: const Icon(Icons.download, color: Colors.white),
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
                                style: const TextStyle(color: Color(0xFFFFB690), fontSize: 17, fontWeight: FontWeight.bold),
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

            const SizedBox(height: 24),

            // Action Buttons
            // 1. Download Ticket Button
            ElevatedButton.icon(
              onPressed: _isDownloading ? null : _showDownloadChoiceModal,
              icon: _isDownloading
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.download, color: Colors.white),
              label: Text(
                _isDownloading ? 'Đang chuẩn bị tệp...' : 'Tải Vé Về Thiết Bị (PNG / SVG)',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryContainer,
                minimumSize: const Size(double.infinity, 48),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
            ),

            const SizedBox(height: 12),

            // 2. Event Reminder Button
            OutlinedButton.icon(
              onPressed: () => _showReminderModal(ticket),
              icon: const Icon(Icons.alarm_on, color: Color(0xFF06B6D4), size: 18),
              label: const Text('Nhận Nhắc Nhở Trước Sự Kiện', style: TextStyle(color: Color(0xFF06B6D4), fontWeight: FontWeight.bold)),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Color(0xFF06B6D4)),
                minimumSize: const Size(double.infinity, 46),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
            ),

            // 3. Feedback button (Function 24)
            if (ticket.isUsed) ...[
              const SizedBox(height: 12),
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

            // 4. Refund button (Function 20)
            if (ticket.isValid && !ticket.isUsed && !ticket.isRefundPending) ...[
              const SizedBox(height: 12),
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
