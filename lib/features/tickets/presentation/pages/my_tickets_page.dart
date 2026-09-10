import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../../../core/api/tickets_service.dart';
import '../../../../core/models/ticket_model.dart';
import '../../../../core/theme/app_colors.dart';

class MyTicketsPage extends StatefulWidget {
  const MyTicketsPage({super.key});

  @override
  State<MyTicketsPage> createState() => _MyTicketsPageState();
}

class _MyTicketsPageState extends State<MyTicketsPage> {
  List<TicketModel> _tickets = [];
  bool _isLoading = true;
  int _selectedFilterTab = 0; // 0: Upcoming, 1: Used/History

  @override
  void initState() {
    super.initState();
    _loadTickets();
  }

  Future<void> _loadTickets() async {
    setState(() => _isLoading = true);
    final list = await TicketsService().getMyTickets();
    setState(() {
      _tickets = list;
      _isLoading = false;
    });
  }

  void _showQrCodeModal(TicketModel ticket) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: Color(0xFF0C1446),
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 20),
            Text(ticket.eventName, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
            const SizedBox(height: 4),
            Text('${ticket.ticketType} • ${ticket.seatName}', style: const TextStyle(color: AppColors.primaryContainer, fontWeight: FontWeight.w600, fontSize: 13)),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(color: AppColors.primaryContainer.withOpacity(0.3), blurRadius: 20),
                ],
              ),
              child: QrImageView(
                data: ticket.ticketCode,
                version: QrVersions.auto,
                size: 200.0,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              ticket.ticketCode,
              style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 2, fontFamily: 'monospace'),
            ),
            const SizedBox(height: 8),
            Text(
              ticket.isUsed ? 'VÉ NÀY ĐÃ ĐƯỢC CHECK-IN TẠI CỔNG' : 'ĐƯA MÃ NÀY CHO NHÂN VIÊN TẠI CỔNG SOÁT VÉ',
              style: TextStyle(color: ticket.isUsed ? AppColors.error : const Color(0xFF22C55E), fontSize: 11, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.surfaceContainerHigh,
                minimumSize: const Size(double.infinity, 46),
              ),
              child: const Text('Đóng', style: TextStyle(color: Colors.white)),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filteredTickets = _tickets.where((t) {
      if (_selectedFilterTab == 0) return t.isValid;
      return t.isUsed;
    }).toList();

    return Scaffold(
      backgroundColor: const Color(0xFF081126),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('Vé Của Tôi', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: AppColors.secondary),
            onPressed: _loadTickets,
          ),
        ],
      ),
      body: Column(
        children: [
          // Filter Tabs
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: const Color(0xFF122155),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _selectedFilterTab = 0),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: _selectedFilterTab == 0 ? AppColors.primaryContainer : Colors.transparent,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'Sắp diễn ra (${_tickets.where((t) => t.isValid).length})',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: _selectedFilterTab == 0 ? Colors.white : AppColors.secondary,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _selectedFilterTab = 1),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: _selectedFilterTab == 1 ? AppColors.primaryContainer : Colors.transparent,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'Lịch sử / Đã dùng (${_tickets.where((t) => t.isUsed).length})',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: _selectedFilterTab == 1 ? Colors.white : AppColors.secondary,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: AppColors.primaryContainer))
                : filteredTickets.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.confirmation_number_outlined, size: 64, color: AppColors.secondary.withOpacity(0.4)),
                            const SizedBox(height: 12),
                            const Text('Chưa có vé nào trong danh mục này', style: TextStyle(color: AppColors.secondary)),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: filteredTickets.length,
                        itemBuilder: (ctx, idx) {
                          final ticket = filteredTickets[idx];
                          return Card(
                            margin: const EdgeInsets.only(bottom: 16),
                            color: const Color(0xFF0C1446),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                              side: BorderSide(color: AppColors.secondary.withOpacity(0.15)),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: ticket.isValid ? Colors.green.withOpacity(0.2) : Colors.red.withOpacity(0.2),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          ticket.formattedStatus,
                                          style: TextStyle(
                                            color: ticket.isValid ? Colors.greenAccent : Colors.redAccent,
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                      Text(
                                        ticket.ticketCode,
                                        style: const TextStyle(color: AppColors.secondary, fontSize: 12, fontFamily: 'monospace'),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    ticket.eventName,
                                    style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                                  ),
                                  const SizedBox(height: 6),
                                  Row(
                                    children: [
                                      const Icon(Icons.confirmation_number, color: AppColors.primaryContainer, size: 16),
                                      const SizedBox(width: 6),
                                      Text('${ticket.ticketType} • ${ticket.seatName}', style: const TextStyle(color: Colors.white70, fontSize: 13)),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      const Icon(Icons.access_time, color: AppColors.secondary, size: 16),
                                      const SizedBox(width: 6),
                                      Text(ticket.sessionTime ?? '', style: const TextStyle(color: AppColors.secondary, fontSize: 12)),
                                    ],
                                  ),
                                  const Divider(color: Colors.white12, height: 24),
                                  ElevatedButton(
                                    onPressed: () => _showQrCodeModal(ticket),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppColors.primaryContainer,
                                      minimumSize: const Size(double.infinity, 42),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                    ),
                                    child: const Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(Icons.qr_code, color: Colors.white, size: 18),
                                        SizedBox(width: 8),
                                        Text('Hiển Thị Mã QR Check-in', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
