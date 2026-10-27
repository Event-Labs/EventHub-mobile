import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../core/api/refunds_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_background.dart';

class MyRefundsPage extends StatefulWidget {
  const MyRefundsPage({super.key});

  @override
  State<MyRefundsPage> createState() => _MyRefundsPageState();
}

class _MyRefundsPageState extends State<MyRefundsPage> {
  List<RefundRequestModel> _refunds = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadRefunds();
  }

  Future<void> _loadRefunds() async {
    setState(() => _isLoading = true);
    final list = await RefundsService().getMyRefundRequests();
    if (mounted) {
      setState(() {
        _refunds = list;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          title: const Text('Lịch Sử Hoàn Vé', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primaryContainer))
          : _refunds.isEmpty
              ? _buildEmptyState()
              : RefreshIndicator(
                  color: AppColors.primaryContainer,
                  backgroundColor: const Color(0xFF101932),
                  onRefresh: _loadRefunds,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _refunds.length,
                    itemBuilder: (ctx, idx) {
                      final item = _refunds[idx];
                      final formatter = NumberFormat.currency(locale: 'vi_VN', symbol: 'đ', decimalDigits: 0);

                      final statusColor = _getStatusColor(item.status);

                      return Container(
                        margin: const EdgeInsets.only(bottom: 14),
                        decoration: BoxDecoration(
                          color: const Color(0xFF101932),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.white.withOpacity(0.08)),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.2),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(16),
                            onTap: () => _showRefundDetailSheet(context, item),
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        item.ticketCode ?? 'Yêu cầu hoàn',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 15,
                                          fontFamily: 'monospace',
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: statusColor.withOpacity(0.15),
                                          borderRadius: BorderRadius.circular(12),
                                          border: Border.all(color: statusColor.withOpacity(0.5)),
                                        ),
                                        child: Text(
                                          item.statusText,
                                          style: TextStyle(
                                            color: statusColor,
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  if (item.eventTitle != null) ...[
                                    const SizedBox(height: 8),
                                    Text(
                                      item.eventTitle!,
                                      style: const TextStyle(
                                        color: Color(0xFFDAE2FF),
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                  const SizedBox(height: 12),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      const Text('Số tiền hoàn dự kiến:', style: TextStyle(color: Color(0xFF8B9CB5), fontSize: 12)),
                                      Text(
                                        formatter.format(item.refundAmount > 0 ? item.refundAmount : item.amount),
                                        style: const TextStyle(color: Color(0xFFE6C17A), fontSize: 15, fontWeight: FontWeight.bold),
                                      ),
                                    ],
                                  ),
                                  if (item.reason != null && item.reason!.isNotEmpty) ...[
                                    const SizedBox(height: 6),
                                    Text(
                                      'Lý do: ${item.reason}',
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(color: Color(0xFFB0CADD), fontSize: 12),
                                    ),
                                  ],
                                  if (item.bankName != null) ...[
                                    const SizedBox(height: 4),
                                    Text(
                                      'Ngân hàng: ${item.bankName} - ${item.bankAccountNumber ?? ''}',
                                      style: const TextStyle(color: Color(0xFF8B9CB5), fontSize: 11),
                                    ),
                                  ],
                                  const SizedBox(height: 10),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    children: [
                                      Text(
                                        'Nhấn để xem chi tiết',
                                        style: TextStyle(color: AppColors.secondary.withOpacity(0.6), fontSize: 11),
                                      ),
                                      const SizedBox(width: 4),
                                      Icon(Icons.chevron_right, size: 14, color: AppColors.secondary.withOpacity(0.6)),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toUpperCase()) {
      case 'REFUNDED':
      case 'COMPLETED':
        return const Color(0xFF22C55E); // Xanh lá
      case 'APPROVED':
        return const Color(0xFF10B981);
      case 'PROCESSING':
        return const Color(0xFF38BDF8); // Xanh lam
      case 'REJECTED':
      case 'FAILED':
        return const Color(0xFFEF4444); // Đỏ
      case 'PENDING':
      case 'REFUND_REQUESTED':
      case 'REFUND_PENDING':
      default:
        return const Color(0xFFF59E0B); // Cam
    }
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return '---';
    final dt = DateTime.tryParse(dateStr)?.toLocal();
    if (dt == null) return dateStr;
    return DateFormat('dd/MM/yyyy - HH:mm').format(dt);
  }

  void _showRefundDetailSheet(BuildContext context, RefundRequestModel item) {
    final formatter = NumberFormat.currency(locale: 'vi_VN', symbol: 'đ', decimalDigits: 0);
    final statusColor = _getStatusColor(item.status);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.85,
          ),
          decoration: const BoxDecoration(
            color: Color(0xFF0F1B47),
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            boxShadow: [
              BoxShadow(
                color: Colors.black54,
                blurRadius: 20,
                offset: Offset(0, -4),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Thanh kéo nhỏ
              Container(
                margin: const EdgeInsets.only(top: 12, bottom: 8),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              // Tiêu đề Sheet
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Chi Tiết Yêu Cầu Hoàn Vé',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white70),
                      onPressed: () => Navigator.pop(ctx),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
              ),
              const Divider(color: Colors.white12, height: 1),

              // Nội dung chi tiết
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Trạng thái nổi bật
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: statusColor.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: statusColor.withOpacity(0.35)),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              item.status.toUpperCase() == 'REFUNDED' || item.status.toUpperCase() == 'COMPLETED'
                                  ? Icons.check_circle_outline
                                  : item.status.toUpperCase() == 'REJECTED' || item.status.toUpperCase() == 'FAILED'
                                      ? Icons.cancel_outlined
                                      : Icons.schedule,
                              color: statusColor,
                              size: 24,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Trạng thái: ${item.statusText}',
                                    style: TextStyle(
                                      color: statusColor,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    item.status.toUpperCase() == 'REFUNDED' || item.status.toUpperCase() == 'COMPLETED'
                                        ? 'Số tiền đã được chuyển vào tài khoản ngân hàng của bạn.'
                                        : item.status.toUpperCase() == 'REJECTED'
                                            ? 'Yêu cầu không được phê duyệt bởi Ban tổ chức.'
                                            : 'Yêu cầu đang chờ Ban tổ chức xem xét và xử lý.',
                                    style: TextStyle(
                                      color: statusColor.withOpacity(0.85),
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Thông tin sự kiện & vé
                      _buildDetailSection(
                        title: 'Thông tin vé',
                        icon: Icons.confirmation_number_outlined,
                        children: [
                          _buildDetailRow('Mã vé:', item.ticketCode ?? '---', isHighlight: true),
                          if (item.eventTitle != null) ...[
                            const SizedBox(height: 6),
                            _buildDetailRow('Sự kiện:', item.eventTitle!),
                          ],
                          const SizedBox(height: 6),
                          _buildDetailRow('Thời gian tạo:', _formatDate(item.createdAt)),
                          if (item.refundedAt != null) ...[
                            const SizedBox(height: 6),
                            _buildDetailRow('Thời gian hoàn:', _formatDate(item.refundedAt)),
                          ],
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Thông tin tài chính hoàn vé
                      _buildDetailSection(
                        title: 'Thông tin hoàn tiền',
                        icon: Icons.monetization_on_outlined,
                        children: [
                          if (item.amount > 0) ...[
                            _buildDetailRow('Giá vé:', formatter.format(item.amount)),
                            const SizedBox(height: 6),
                          ],
                          if (item.refundFee > 0) ...[
                            _buildDetailRow('Phí hoàn vé:', formatter.format(item.refundFee)),
                            const SizedBox(height: 6),
                          ],
                          _buildDetailRow(
                            'Số tiền hoàn nhận:',
                            formatter.format(item.refundAmount > 0 ? item.refundAmount : item.amount),
                            valueColor: const Color(0xFFE6C17A),
                            isBold: true,
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Lý do yêu cầu
                      if (item.reason != null && item.reason!.isNotEmpty) ...[
                        _buildDetailSection(
                          title: 'Lý do hoàn vé',
                          icon: Icons.help_outline,
                          children: [
                            Text(
                              item.reason!,
                              style: const TextStyle(color: Colors.white, fontSize: 13, height: 1.4),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                      ],

                      // Thông tin tài khoản nhận tiền
                      _buildDetailSection(
                        title: 'Tài khoản nhận tiền',
                        icon: Icons.account_balance_outlined,
                        children: [
                          _buildDetailRow('Ngân hàng:', item.bankName ?? '---'),
                          const SizedBox(height: 6),
                          _buildDetailRow('Số tài khoản:', item.bankAccountNumber ?? '---', isHighlight: true),
                          if (item.bankAccountName != null && item.bankAccountName!.isNotEmpty) ...[
                            const SizedBox(height: 6),
                            _buildDetailRow('Chủ tài khoản:', item.bankAccountName!),
                          ],
                        ],
                      ),

                      // Ghi chú / Phản hồi từ Ban tổ chức (nếu có)
                      if (item.organizerNote != null && item.organizerNote!.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        _buildDetailSection(
                          title: 'Phản hồi từ Ban Tổ Chức',
                          icon: Icons.speaker_notes_outlined,
                          children: [
                            Text(
                              item.organizerNote!,
                              style: const TextStyle(color: Color(0xFFFCA5A5), fontSize: 13, height: 1.4),
                            ),
                          ],
                        ),
                      ],

                      // Mã tham chiếu giao dịch (nếu có)
                      if (item.transactionRef != null && item.transactionRef!.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        _buildDetailSection(
                          title: 'Mã giao dịch ngân hàng',
                          icon: Icons.receipt_long_outlined,
                          children: [
                            Text(
                              item.transactionRef!,
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                                fontFamily: 'monospace',
                              ),
                            ),
                          ],
                        ),
                      ],

                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton(
                          onPressed: () => Navigator.pop(ctx),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF1A2756),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                              side: const BorderSide(color: Colors.white24),
                            ),
                          ),
                          child: const Text('Đóng', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDetailSection({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF0C1446),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: const Color(0xFFE6C17A)),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  color: Color(0xFFE6C17A),
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ...children,
        ],
      ),
    );
  }

  Widget _buildDetailRow(
    String label,
    String value, {
    bool isHighlight = false,
    bool isBold = false,
    Color? valueColor,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(color: Color(0xFF8B9CB5), fontSize: 12),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: TextStyle(
              color: valueColor ?? (isHighlight ? const Color(0xFFDAE2FF) : Colors.white),
              fontSize: 12,
              fontFamily: isHighlight ? 'monospace' : null,
              fontWeight: isBold ? FontWeight.bold : FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.replay_circle_filled_outlined, color: Colors.white24, size: 54),
          SizedBox(height: 16),
          Text('Chưa có yêu cầu hoàn vé nào', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
          SizedBox(height: 6),
          Text('Các yêu cầu hủy hoặc hoàn vé của bạn sẽ được hiển thị tại đây.', style: TextStyle(color: Color(0xFF8B9CB5), fontSize: 12)),
        ],
      ),
    );
  }
}
