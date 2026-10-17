import 'package:flutter/material.dart';
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
  TicketModel? _ticket;
  bool _isLoading = false;

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
      const SnackBar(content: Text('Đã sao chép mã vé vào bộ nhớ tạm'), duration: Duration(seconds: 1)),
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
                    child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2))),
                  ),
                  const SizedBox(height: 20),
                  const Text('Yêu Cầu Hoàn Vé', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  Text(
                    'Vé: ${ticket.ticketCode} (${ticket.ticketType})',
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

                            setModalState(() => isSubmitting = true);
                            final res = await RefundsService().submitRefundRequest(
                              ticketId: ticket.ticketId,
                              reason: reason,
                              bankName: bank,
                              bankAccountNumber: acc,
                              bankAccountName: accName,
                            );
                            setModalState(() => isSubmitting = false);

                            if (!mounted) return;
                            if (ctx.mounted) {
                              Navigator.pop(ctx);
                            }
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(res['message'] ?? 'Đã gửi yêu cầu hoàn vé'),
                                backgroundColor: res['success'] == true ? Colors.green : AppColors.error,
                              ),
                            );
                            _loadTicket();
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

    Color statusColor;
    if (ticket.isUsed) {
      statusColor = const Color(0xFF06B6D4);
    } else if (ticket.isRefundRequested) {
      statusColor = Colors.orange;
    } else if (ticket.isRefunded) {
      statusColor = Colors.purpleAccent;
    } else if (ticket.isValid) {
      statusColor = const Color(0xFF22C55E);
    } else {
      statusColor = AppColors.error;
    }

    return Scaffold(
      backgroundColor: const Color(0xFF070D1E),
      appBar: AppBar(
        backgroundColor: const Color(0xFF070D1E),
        elevation: 0,
        title: const Text('Chi Tiết Vé Điện Tử', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // Ticket container
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFF101932),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: Colors.white.withOpacity(0.08)),
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 24, offset: const Offset(0, 10)),
                ],
              ),
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: [
                  // Event Header
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          const Color(0xFF1A284D),
                          const Color(0xFF101932),
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
                                color: statusColor.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: statusColor.withOpacity(0.5)),
                              ),
                              child: Text(
                                ticket.formattedStatus.toUpperCase(),
                                style: TextStyle(color: statusColor, fontSize: 11, fontWeight: FontWeight.bold),
                              ),
                            ),
                            Text(
                              ticket.formattedPrice,
                              style: const TextStyle(color: Color(0xFFFFB690), fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          ticket.eventName,
                          style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold, height: 1.3),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '${ticket.ticketType} • ${ticket.seatName}',
                          style: const TextStyle(color: Color(0xFFE6C17A), fontSize: 13, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),

                  // Tear line with cutouts
                  Row(
                    children: [
                      Container(width: 14, height: 28, decoration: const BoxDecoration(color: Color(0xFF070D1E), borderRadius: BorderRadius.horizontal(right: Radius.circular(14)))),
                      Expanded(
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            return Flex(
                              direction: Axis.horizontal,
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: List.generate(
                                (constraints.constrainWidth() / 10).floor(),
                                (_) => const SizedBox(width: 5, height: 1.5, child: DecoratedBox(decoration: BoxDecoration(color: Colors.white12))),
                              ),
                            );
                          },
                        ),
                      ),
                      Container(width: 14, height: 28, decoration: const BoxDecoration(color: Color(0xFF070D1E), borderRadius: BorderRadius.horizontal(left: Radius.circular(14)))),
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
                              BoxShadow(color: AppColors.primaryContainer.withOpacity(0.2), blurRadius: 20),
                            ],
                          ),
                          child: QrImageView(
                            data: ticket.qrPayload,
                            version: QrVersions.auto,
                            size: 200,
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
                                style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold, letterSpacing: 2, fontFamily: 'monospace'),
                              ),
                              const SizedBox(width: 8),
                              const Icon(Icons.copy, color: Color(0xFFB0CADD), size: 16),
                            ],
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          ticket.isUsed
                              ? 'Vé đã được quét tại cổng soát vé'
                              : 'Vui lòng xuất trình mã này cho nhân viên tại cổng',
                          style: TextStyle(color: ticket.isUsed ? const Color(0xFF06B6D4) : const Color(0xFF22C55E), fontSize: 11, fontWeight: FontWeight.bold),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),

                  // Detail rows
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      children: [
                        const Divider(color: Colors.white12, height: 1),
                        const SizedBox(height: 16),
                        _buildInfoTile('Thời gian:', ticket.formattedSessionTime, Icons.access_time),
                        _buildInfoTile('Địa điểm:', ticket.venue?.summary ?? 'TP. Hồ Chí Minh', Icons.location_on),
                        _buildInfoTile('Người sở hữu:', ticket.attendeeName ?? 'Khách hàng', Icons.person),
                        if (ticket.attendeeEmail != null && ticket.attendeeEmail!.isNotEmpty)
                          _buildInfoTile('Email:', ticket.attendeeEmail!, Icons.email),
                        if (ticket.checkInTime != null)
                          _buildInfoTile('Thời gian check-in:', ticket.checkInTime!, Icons.check_circle_outline),
                        const SizedBox(height: 16),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Action Buttons
            if (ticket.isUsed)
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => FeedbackPage(initialEventId: ticket.eventId)),
                  );
                },
                icon: const Icon(Icons.star, color: Colors.white),
                label: const Text('Đánh Giá Sự Kiện', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryContainer,
                  minimumSize: const Size(double.infinity, 48),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
              ),

            if (ticket.isValid && !ticket.isUsed && !ticket.isRefundRequested) ...[
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: () => _showRefundModal(ticket),
                icon: const Icon(Icons.replay, color: Color(0xFFE6C17A), size: 18),
                label: const Text('Yêu Cầu Hoàn Vé', style: TextStyle(color: Color(0xFFE6C17A), fontWeight: FontWeight.bold)),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: const Color(0xFFE6C17A).withOpacity(0.5)),
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
            width: 110,
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
