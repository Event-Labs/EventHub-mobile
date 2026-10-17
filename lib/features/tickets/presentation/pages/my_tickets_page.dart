import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../../../core/api/tickets_service.dart';
import '../../../../core/models/ticket_model.dart';
import '../../../../core/theme/app_colors.dart';
import 'ticket_detail_page.dart';

class MyTicketsPage extends StatefulWidget {
  const MyTicketsPage({super.key});

  @override
  State<MyTicketsPage> createState() => _MyTicketsPageState();
}

class _MyTicketsPageState extends State<MyTicketsPage> {
  List<TicketModel> _tickets = [];
  bool _isLoading = true;
  int _selectedFilterTab = 0; // 0: Upcoming, 1: Used/Expired, 2: Refunds

  @override
  void initState() {
    super.initState();
    _loadTickets();
  }

  Future<void> _loadTickets() async {
    setState(() => _isLoading = true);
    final list = await TicketsService().getMyTickets();
    if (mounted) {
      setState(() {
        _tickets = list;
        _isLoading = false;
      });
    }
  }

  void _showQuickQr(TicketModel ticket) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: Color(0xFF0F1A38),
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 20),
            Text(ticket.eventName, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
            const SizedBox(height: 4),
            Text('${ticket.ticketType} • ${ticket.seatName}', style: const TextStyle(color: Color(0xFFE6C17A), fontWeight: FontWeight.w600, fontSize: 13)),
            const SizedBox(height: 20),
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
            Text(
              ticket.ticketCode,
              style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold, letterSpacing: 2, fontFamily: 'monospace'),
            ),
            const SizedBox(height: 8),
            Text(
              ticket.isUsed ? 'VÉ ĐÃ ĐƯỢC CHECK-IN TẠI CỔNG' : 'XUẤT TRÌNH MÃ NÀY TẠI CỔNG SOÁT VÉ',
              style: TextStyle(color: ticket.isUsed ? const Color(0xFF06B6D4) : const Color(0xFF22C55E), fontSize: 11, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => TicketDetailPage(ticketId: ticket.ticketId, initialTicket: ticket)),
                ).then((_) => _loadTickets());
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryContainer,
                minimumSize: const Size(double.infinity, 46),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              child: const Text('Xem Toàn Bộ Chi Tiết Vé', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filteredTickets = _tickets.where((t) {
      if (_selectedFilterTab == 0) return t.isValid;
      if (_selectedFilterTab == 1) return t.isUsed || t.isExpired;
      return t.isRefundRequested || t.isRefunded;
    }).toList();

    return Scaffold(
      backgroundColor: const Color(0xFF070D1E),
      appBar: AppBar(
        backgroundColor: const Color(0xFF070D1E),
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'Vé Của Tôi',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 20),
        ),
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
                  _buildTabItem(0, 'Sắp diễn ra'),
                  _buildTabItem(1, 'Đã dùng / Hết hạn'),
                  _buildTabItem(2, 'Hoàn vé'),
                ],
              ),
            ),
          ),

          // Tickets List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: AppColors.primaryContainer))
                : filteredTickets.isEmpty
                    ? _buildEmptyState()
                    : RefreshIndicator(
                        color: AppColors.primaryContainer,
                        backgroundColor: const Color(0xFF101932),
                        onRefresh: _loadTickets,
                        child: ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: filteredTickets.length,
                          itemBuilder: (ctx, idx) {
                            final ticket = filteredTickets[idx];
                            return _buildTicketCard(ticket);
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabItem(int index, String label) {
    final isSelected = _selectedFilterTab == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedFilterTab = index),
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

  Widget _buildTicketCard(TicketModel ticket) {
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

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => TicketDetailPage(ticketId: ticket.ticketId, initialTicket: ticket)),
        ).then((_) => _loadTickets());
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: const Color(0xFF101932),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withOpacity(0.08)),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 16, offset: const Offset(0, 6)),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
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
                          border: Border.all(color: statusColor.withOpacity(0.4)),
                        ),
                        child: Text(
                          ticket.formattedStatus.toUpperCase(),
                          style: TextStyle(color: statusColor, fontSize: 10, fontWeight: FontWeight.bold),
                        ),
                      ),
                      Text(
                        ticket.formattedPrice,
                        style: const TextStyle(color: Color(0xFFFFB690), fontSize: 15, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    ticket.eventName,
                    style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.confirmation_number_outlined, color: Color(0xFFE6C17A), size: 14),
                      const SizedBox(width: 6),
                      Text(
                        '${ticket.ticketType} • ${ticket.seatName}',
                        style: const TextStyle(color: Color(0xFFE6C17A), fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(Icons.access_time, color: Color(0xFFB0CADD), size: 14),
                      const SizedBox(width: 6),
                      Text(
                        ticket.formattedSessionTime,
                        style: const TextStyle(color: Color(0xFFB0CADD), fontSize: 12),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(Icons.location_on, color: Color(0xFFB0CADD), size: 14),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          ticket.venue?.summary ?? 'TP. Hồ Chí Minh',
                          style: const TextStyle(color: Color(0xFFB0CADD), fontSize: 12),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Card Bottom actions
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFF16254F),
                border: Border(top: BorderSide(color: Colors.white.withOpacity(0.06))),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.qr_code, color: Colors.white70, size: 16),
                      const SizedBox(width: 6),
                      Text(
                        ticket.ticketCode,
                        style: const TextStyle(color: Colors.white70, fontSize: 12, fontFamily: 'monospace', fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      TextButton.icon(
                        onPressed: () => _showQuickQr(ticket),
                        icon: const Icon(Icons.qr_code_scanner, color: AppColors.primaryContainer, size: 16),
                        label: const Text('Xem QR', style: TextStyle(color: AppColors.primaryContainer, fontSize: 12, fontWeight: FontWeight.bold)),
                      ),
                      const SizedBox(width: 4),
                      const Icon(Icons.chevron_right, color: Colors.white38, size: 18),
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
    String message = 'Không có vé nào trong mục này';
    if (_selectedFilterTab == 0) message = 'Bạn chưa có vé sắp diễn ra nào. Hãy khám phá và đặt vé ngay!';
    if (_selectedFilterTab == 1) message = 'Chưa có lịch sử vé đã sử dụng.';
    if (_selectedFilterTab == 2) message = 'Không có yêu cầu hoàn vé nào.';

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
              child: const Icon(Icons.confirmation_number_outlined, color: AppColors.secondary, size: 48),
            ),
            const SizedBox(height: 20),
            Text(
              message,
              style: const TextStyle(color: Color(0xFFB0CADD), fontSize: 14),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
