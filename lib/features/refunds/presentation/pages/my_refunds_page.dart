import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../core/api/refunds_service.dart';
import '../../../../core/theme/app_colors.dart';

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
    return Scaffold(
      backgroundColor: const Color(0xFF070D1E),
      appBar: AppBar(
        backgroundColor: const Color(0xFF070D1E),
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

                      Color statusColor;
                      switch (item.status) {
                        case 'APPROVED':
                        case 'COMPLETED':
                          statusColor = const Color(0xFF22C55E);
                          break;
                        case 'REJECTED':
                          statusColor = AppColors.error;
                          break;
                        case 'PENDING':
                        default:
                          statusColor = Colors.orange;
                          break;
                      }

                      return Container(
                        margin: const EdgeInsets.only(bottom: 14),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFF101932),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.white.withOpacity(0.08)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  item.ticketCode ?? 'Yêu cầu hoàn',
                                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15, fontFamily: 'monospace'),
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
                                    style: TextStyle(color: statusColor, fontSize: 11, fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ],
                            ),
                            if (item.eventTitle != null) ...[
                              const SizedBox(height: 8),
                              Text(item.eventTitle!, style: const TextStyle(color: Color(0xFFDAE2FF), fontSize: 13, fontWeight: FontWeight.w600)),
                            ],
                            const SizedBox(height: 12),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('Số tiền hoàn dự kiến:', style: TextStyle(color: Color(0xFF8B9CB5), fontSize: 12)),
                                Text(
                                  formatter.format(item.refundAmount > 0 ? item.refundAmount : item.amount),
                                  style: const TextStyle(color: Color(0xFFFFB690), fontSize: 15, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                            if (item.reason != null && item.reason!.isNotEmpty) ...[
                              const SizedBox(height: 6),
                              Text('Lý do: ${item.reason}', style: const TextStyle(color: Color(0xFFB0CADD), fontSize: 12)),
                            ],
                            if (item.bankName != null) ...[
                              const SizedBox(height: 4),
                              Text('Ngân hàng: ${item.bankName} - ${item.bankAccountNumber ?? ''}', style: const TextStyle(color: Color(0xFF8B9CB5), fontSize: 11)),
                            ],
                          ],
                        ),
                      );
                    },
                  ),
                ),
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
