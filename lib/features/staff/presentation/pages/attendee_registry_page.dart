import 'package:flutter/material.dart';
import '../../../../core/api/staff_service.dart';
import '../../../../core/models/ticket_model.dart';
import '../../../../core/theme/app_colors.dart';

class AttendeeRegistryPage extends StatefulWidget {
  const AttendeeRegistryPage({super.key});

  @override
  State<AttendeeRegistryPage> createState() => _AttendeeRegistryPageState();
}

class _AttendeeRegistryPageState extends State<AttendeeRegistryPage> {
  final _searchController = TextEditingController();
  List<TicketModel> _tickets = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _performSearch('');
  }

  Future<void> _performSearch(String query) async {
    setState(() => _isLoading = true);
    final results = await StaffService().searchTickets(query);
    setState(() {
      _tickets = results;
      _isLoading = false;
    });
  }

  Future<void> _handleManualCheckIn(TicketModel ticket) async {
    final res = await StaffService().manualCheckIn(ticket.ticketId);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(res['message']),
          backgroundColor: res['success'] ? Colors.green : AppColors.error,
        ),
      );
      if (res['success']) {
        _performSearch(_searchController.text);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF081126),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0C1446),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Danh Sách Người Tham Dự', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
      body: Column(
        children: [
          // Search Input Bar
          Container(
            padding: const EdgeInsets.all(16),
            color: const Color(0xFF0C1446),
            child: Container(
              height: 48,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: const Color(0xFF122155),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.search, color: AppColors.secondary, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      style: const TextStyle(color: Colors.white),
                      onChanged: (val) => _performSearch(val),
                      decoration: const InputDecoration(
                        hintText: 'Tìm theo tên khách, email, mã vé...',
                        hintStyle: TextStyle(color: Colors.white38, fontSize: 13),
                        border: InputBorder.none,
                      ),
                    ),
                  ),
                  if (_searchController.text.isNotEmpty)
                    IconButton(
                      icon: const Icon(Icons.clear, color: AppColors.secondary, size: 18),
                      onPressed: () {
                        _searchController.clear();
                        _performSearch('');
                      },
                    ),
                ],
              ),
            ),
          ),

          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: AppColors.primaryContainer))
                : _tickets.isEmpty
                    ? const Center(
                        child: Text('Không tìm thấy người tham dự phù hợp', style: TextStyle(color: AppColors.secondary)),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _tickets.length,
                        itemBuilder: (ctx, idx) {
                          final item = _tickets[idx];
                          return Card(
                            margin: const EdgeInsets.only(bottom: 12),
                            color: const Color(0xFF0C1446),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                              side: BorderSide(color: AppColors.secondary.withOpacity(0.15)),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(14),
                              child: Row(
                                children: [
                                  CircleAvatar(
                                    radius: 20,
                                    backgroundColor: const Color(0xFF122155),
                                    child: Text(
                                      item.customerName?.isNotEmpty == true ? item.customerName![0].toUpperCase() : 'U',
                                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(item.customerName ?? 'Khách hàng', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                                        const SizedBox(height: 2),
                                        Text('${item.ticketType} • ${item.seatName}', style: const TextStyle(color: AppColors.secondary, fontSize: 11)),
                                        Text(item.ticketCode, style: const TextStyle(color: AppColors.primaryContainer, fontSize: 11, fontFamily: 'monospace', fontWeight: FontWeight.bold)),
                                      ],
                                    ),
                                  ),
                                  item.isUsed
                                      ? Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                          decoration: BoxDecoration(
                                            color: Colors.green.withOpacity(0.15),
                                            borderRadius: BorderRadius.circular(8),
                                            border: Border.all(color: Colors.greenAccent.withOpacity(0.3)),
                                          ),
                                          child: const Text('ĐÃ CHECK-IN', style: TextStyle(color: Colors.greenAccent, fontSize: 10, fontWeight: FontWeight.bold)),
                                        )
                                      : ElevatedButton(
                                          onPressed: () => _handleManualCheckIn(item),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: AppColors.primaryContainer,
                                            minimumSize: const Size(80, 36),
                                            padding: const EdgeInsets.symmetric(horizontal: 10),
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                          ),
                                          child: const Text('Check-in', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
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
