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
  List<TicketModel> _allTickets = [];
  bool _isLoading = true;
  String _selectedStatus = 'ALL';

  final List<Map<String, String>> _statusFilters = [
    {'key': 'ALL', 'label': 'Tất cả'},
    {'key': 'VALID', 'label': 'Hợp lệ'},
    {'key': 'USED', 'label': 'Đã dùng'},
    {'key': 'REFUND_PENDING', 'label': 'Chờ hoàn tiền'},
    {'key': 'REFUNDED', 'label': 'Đã hoàn'},
    {'key': 'EXPIRED', 'label': 'Hết hạn'},
    {'key': 'CANCELLED', 'label': 'Đã hủy'},
  ];

  @override
  void initState() {
    super.initState();
    _loadTickets();
  }

  Future<void> _loadTickets() async {
    setState(() => _isLoading = true);
    final list = await TicketsService().getMyTickets(status: _selectedStatus == 'ALL' ? null : _selectedStatus);
    if (mounted) {
      setState(() {
        _allTickets = list;
        _isLoading = false;
      });
    }
  }

  List<TicketModel> get _filteredTickets {
    if (_selectedStatus == 'ALL') return _allTickets;
    return _allTickets.where((t) {
      if (_selectedStatus == 'VALID') return t.isValid;
      if (_selectedStatus == 'USED') return t.isUsed;
      if (_selectedStatus == 'REFUND_PENDING') return t.isRefundPending;
      if (_selectedStatus == 'REFUNDED') return t.isRefunded;
      if (_selectedStatus == 'EXPIRED') return t.isExpired;
      if (_selectedStatus == 'CANCELLED') return t.isCancelled;
      return t.status == _selectedStatus;
    }).toList();
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
            Container(
              width: 44,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              ticket.eventName,
              style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFE6C17A).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE6C17A).withValues(alpha: 0.4)),
              ),
              child: Text(
                '${ticket.ticketType ?? "Vé tham dự"} • ${ticket.seatName ?? "GA"}',
                style: const TextStyle(color: Color(0xFFE6C17A), fontWeight: FontWeight.bold, fontSize: 12),
              ),
            ),
            const SizedBox(height: 22),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primaryContainer.withValues(alpha: 0.25),
                    blurRadius: 24,
                    offset: const Offset(0, 8),
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
            Text(
              ticket.ticketCode,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
                letterSpacing: 2.5,
                fontFamily: 'monospace',
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  ticket.isUsed ? Icons.check_circle : Icons.qr_code_scanner,
                  color: ticket.statusColor,
                  size: 16,
                ),
                const SizedBox(width: 6),
                Text(
                  ticket.isUsed
                      ? 'VÉ ĐÃ ĐƯỢC CHECK-IN TẠI CỔNG'
                      : ticket.isRefundPending
                          ? 'VÉ ĐANG ĐƯỢC XÉT DUYỆT HOÀN TIỀN'
                          : 'XUẤT TRÌNH MÃ NÀY TẠI CỔNG SOÁT VÉ',
                  style: TextStyle(
                    color: ticket.statusColor,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.pop(ctx);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => TicketDetailPage(ticketId: ticket.ticketId, initialTicket: ticket),
                  ),
                ).then((_) => _loadTickets());
              },
              icon: const Icon(Icons.info_outline, color: Colors.white, size: 18),
              label: const Text('Xem Chi Tiết & Tải Vé', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryContainer,
                minimumSize: const Size(double.infinity, 48),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tickets = _filteredTickets;

    return Scaffold(
      backgroundColor: const Color(0xFF070D1E),
      appBar: AppBar(
        backgroundColor: const Color(0xFF070D1E),
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Vé Của Tôi',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 20),
            ),
            Text(
              'Quản lý vé đã mua & mã QR check-in',
              style: TextStyle(color: Color(0xFF8B9CB5), fontSize: 11),
            ),
          ],
        ),
        actions: [
          IconButton(
            onPressed: _loadTickets,
            icon: const Icon(Icons.refresh, color: Color(0xFFB0CADD)),
            tooltip: 'Làm mới',
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: Column(
        children: [
          // Filter Chips Horizontal Scroll
          Container(
            height: 48,
            margin: const EdgeInsets.symmetric(vertical: 8),
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _statusFilters.length,
              itemBuilder: (ctx, idx) {
                final filter = _statusFilters[idx];
                final isSelected = _selectedStatus == filter['key'];
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    selected: isSelected,
                    label: Text(filter['label']!),
                    labelStyle: TextStyle(
                      color: isSelected ? const Color(0xFF070D1E) : const Color(0xFFB0CADD),
                      fontSize: 12,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                    ),
                    backgroundColor: const Color(0xFF101932),
                    selectedColor: const Color(0xFFE6C17A),
                    checkmarkColor: const Color(0xFF070D1E),
                    side: BorderSide(
                      color: isSelected ? const Color(0xFFE6C17A) : Colors.white.withValues(alpha: 0.1),
                    ),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    onSelected: (selected) {
                      setState(() {
                        _selectedStatus = filter['key']!;
                      });
                      _loadTickets();
                    },
                  ),
                );
              },
            ),
          ),

          // Tickets List View
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: AppColors.primaryContainer))
                : tickets.isEmpty
                    ? _buildEmptyState()
                    : RefreshIndicator(
                        color: AppColors.primaryContainer,
                        backgroundColor: const Color(0xFF101932),
                        onRefresh: _loadTickets,
                        child: ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: tickets.length,
                          itemBuilder: (ctx, idx) {
                            return _buildTicketCard(tickets[idx]);
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildTicketCard(TicketModel ticket) {
    final statusColor = ticket.statusColor;

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => TicketDetailPage(ticketId: ticket.ticketId, initialTicket: ticket),
          ),
        ).then((_) => _loadTickets());
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: const Color(0xFF101932),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.35),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
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
                  // Top badge & Price
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: statusColor.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: statusColor.withValues(alpha: 0.4)),
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

                  // Event title
                  Text(
                    ticket.eventName,
                    style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 10),

                  // Ticket Type & Seat
                  Row(
                    children: [
                      const Icon(Icons.confirmation_number_outlined, color: Color(0xFFE6C17A), size: 14),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          '${ticket.ticketType ?? "Vé tham dự"} • ${ticket.seatName ?? "GA"}',
                          style: const TextStyle(color: Color(0xFFE6C17A), fontSize: 12, fontWeight: FontWeight.w600),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),

                  // Session Time
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

                  // Venue
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
                border: Border(top: BorderSide(color: Colors.white.withValues(alpha: 0.06))),
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
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                          fontFamily: 'monospace',
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      TextButton.icon(
                        onPressed: () => _showQuickQr(ticket),
                        icon: const Icon(Icons.qr_code_scanner, color: AppColors.primaryContainer, size: 16),
                        label: const Text(
                          'Mã QR',
                          style: TextStyle(color: AppColors.primaryContainer, fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                      ),
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
    String message = 'Hiện không có vé sự kiện nào trong danh sách.';
    final currentFilterLabel = _statusFilters.firstWhere((f) => f['key'] == _selectedStatus, orElse: () => {'label': ''})['label'];
    if (_selectedStatus != 'ALL') {
      message = 'Hiện không có vé sự kiện nào thuộc mục "$currentFilterLabel".';
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
              child: const Icon(Icons.confirmation_number_outlined, color: Color(0xFFE6C17A), size: 48),
            ),
            const SizedBox(height: 20),
            Text(
              message,
              style: const TextStyle(color: Color(0xFFB0CADD), fontSize: 14),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            if (_selectedStatus != 'ALL')
              OutlinedButton(
                onPressed: () {
                  setState(() => _selectedStatus = 'ALL');
                  _loadTickets();
                },
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Color(0xFFE6C17A)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Xem tất cả vé', style: TextStyle(color: Color(0xFFE6C17A))),
              ),
          ],
        ),
      ),
    );
  }
}
