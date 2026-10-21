import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../core/api/auth_service.dart';
import '../../../../core/api/staff_service.dart';
import '../../../../core/models/ticket_model.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../home/presentation/pages/home_discovery_page.dart';

class AttendeeRegistryPage extends StatefulWidget {
  final String? eventId;
  final String? eventTitle;
  final Map<String, dynamic>? initialEvent;

  const AttendeeRegistryPage({
    super.key,
    this.eventId,
    this.eventTitle,
    this.initialEvent,
  });

  @override
  State<AttendeeRegistryPage> createState() => _AttendeeRegistryPageState();
}

class _AttendeeRegistryPageState extends State<AttendeeRegistryPage> {
  final _searchController = TextEditingController();
  final _ticketCodeController = TextEditingController();
  final _buyerNameController = TextEditingController();
  final _buyerEmailController = TextEditingController();
  final _buyerPhoneController = TextEditingController();

  List<Map<String, dynamic>> _assignedEvents = [];
  Map<String, dynamic>? _selectedEvent;
  bool _isLoadingEvents = true;
  String? _eventsError;

  List<TicketModel> _tickets = [];
  bool _isLoadingTickets = false;
  String? _ticketsError;
  String? _checkinNotice;

  // Filter tab: 'all', 'valid' (un-checked), 'used' (checked-in)
  String _activeStatusFilter = 'all';
  Timer? _debounceTimer;
  final Set<String> _checkingInTicketIds = {};

  final _dateTimeFormat = DateFormat('HH:mm - dd/MM/yyyy');
  final _timeFormat = DateFormat('HH:mm:ss');

  @override
  void initState() {
    super.initState();
    _checkAuthAndLoad();
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _searchController.dispose();
    _ticketCodeController.dispose();
    _buyerNameController.dispose();
    _buyerEmailController.dispose();
    _buyerPhoneController.dispose();
    super.dispose();
  }

  void _checkAuthAndLoad() {
    final user = AuthService().currentUser;
    if (user == null || !user.canAccessStaff) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Tài khoản của bạn chỉ có quyền Khách hàng, không thể vào Cổng Nhân sự!'),
            backgroundColor: AppColors.error,
          ),
        );
        if (Navigator.of(context).canPop()) {
          Navigator.of(context).pop();
        } else {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const HomeDiscoveryPage()),
          );
        }
      });
      return;
    }

    _loadAssignedEvents();
  }

  Future<void> _loadAssignedEvents() async {
    setState(() {
      _isLoadingEvents = true;
      _eventsError = null;
    });

    try {
      final events = await StaffService().getAssignedEvents();
      if (!mounted) return;

      _assignedEvents = events;
      _isLoadingEvents = false;

      if (_assignedEvents.isEmpty) {
        _eventsError = 'Bạn chưa được phân công vào sự kiện nào đang hoạt động.';
        setState(() {});
        return;
      }

      // Pre-select matching event if eventId was provided
      final targetId = widget.eventId ?? widget.initialEvent?['id']?.toString();
      if (targetId != null && targetId.isNotEmpty) {
        final match = _assignedEvents.firstWhere(
          (e) => e['id']?.toString() == targetId,
          orElse: () => _assignedEvents.first,
        );
        _selectedEvent = match;
      } else {
        _selectedEvent = _assignedEvents.first;
      }

      setState(() {});
      _fetchTicketsForSelectedEvent();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoadingEvents = false;
        _eventsError = 'Không thể tải danh sách sự kiện được phân công.';
      });
    }
  }

  void _onEventSelected(Map<String, dynamic> event) {
    if (_selectedEvent?['id'] == event['id']) return;
    setState(() {
      _selectedEvent = event;
      _searchController.clear();
      _ticketCodeController.clear();
      _buyerNameController.clear();
      _buyerEmailController.clear();
      _buyerPhoneController.clear();
    });
    _fetchTicketsForSelectedEvent();
  }

  Future<void> _fetchTicketsForSelectedEvent() async {
    final event = _selectedEvent;
    if (event == null) {
      setState(() {
        _tickets = [];
        _isLoadingTickets = false;
        _ticketsError = 'Vui lòng chọn sự kiện trước khi tải danh sách vé.';
        _checkinNotice = null;
      });
      return;
    }

    final eventId = event['id']?.toString() ?? '';
    if (eventId.isEmpty) return;

    // Check check-in start time
    final checkinStartStr = event['checkin_start_time'] ?? event['start_time'];
    final checkinStartTime = checkinStartStr != null ? DateTime.tryParse(checkinStartStr.toString()) : null;
    if (checkinStartTime != null && checkinStartTime.isAfter(DateTime.now())) {
      setState(() {
        _tickets = [];
        _isLoadingTickets = false;
        _ticketsError = null;
        _checkinNotice = 'Sự kiện này chưa đến giờ mở check-in.\nThời gian mở check-in dự kiến: ${_dateTimeFormat.format(checkinStartTime.toLocal())}.';
      });
      return;
    } else {
      _checkinNotice = null;
    }

    setState(() {
      _isLoadingTickets = true;
      _ticketsError = null;
    });

    try {
      final results = await StaffService().searchTicketsWithFilters(
        eventId: eventId,
        query: _searchController.text.trim().isNotEmpty ? _searchController.text.trim() : null,
        ticketCode: _ticketCodeController.text.trim().isNotEmpty ? _ticketCodeController.text.trim() : null,
        buyerName: _buyerNameController.text.trim().isNotEmpty ? _buyerNameController.text.trim() : null,
        buyerEmail: _buyerEmailController.text.trim().isNotEmpty ? _buyerEmailController.text.trim() : null,
        buyerPhone: _buyerPhoneController.text.trim().isNotEmpty ? _buyerPhoneController.text.trim() : null,
      );

      if (!mounted) return;
      setState(() {
        _tickets = results;
        _isLoadingTickets = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _tickets = [];
        _isLoadingTickets = false;
        _ticketsError = 'Không thể tải danh sách vé: $e';
      });
    }
  }

  void _onSearchChanged(String value) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 350), () {
      _fetchTicketsForSelectedEvent();
    });
  }

  Future<void> _handleManualCheckIn(TicketModel ticket) async {
    if (_checkingInTicketIds.contains(ticket.ticketId)) return;

    setState(() => _checkingInTicketIds.add(ticket.ticketId));

    final gate = _selectedEvent?['gate']?.toString() ?? 'GATE 01';
    final res = await StaffService().manualCheckIn(ticket.ticketId, gate: gate);

    if (!mounted) return;
    setState(() => _checkingInTicketIds.remove(ticket.ticketId));

    if (res['success'] == true) {
      final updatedTicket = res['ticket'] is TicketModel ? (res['ticket'] as TicketModel) : null;

      // Update in local list immediately
      setState(() {
        final idx = _tickets.indexWhere((t) => t.ticketId == ticket.ticketId);
        if (idx != -1) {
          if (updatedTicket != null) {
            _tickets[idx] = updatedTicket;
          } else {
            // Fallback: reload
            _fetchTicketsForSelectedEvent();
          }
        }
      });

      _showCheckInSuccessModal(updatedTicket ?? ticket);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(res['message'] ?? 'Không thể soát vé này!'),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _showCheckInSuccessModal(TicketModel ticket) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0F1A36),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 28,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 48,
                height: 5,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.greenAccent.withValues(alpha: 0.15),
                  border: Border.all(color: Colors.greenAccent.withValues(alpha: 0.4), width: 2),
                ),
                child: const Icon(Icons.check_circle_rounded, color: Colors.greenAccent, size: 48),
              ),
              const SizedBox(height: 14),
              const Text(
                'CHECK-IN THÀNH CÔNG',
                style: TextStyle(
                  color: Colors.greenAccent,
                  fontWeight: FontWeight.w900,
                  fontSize: 18,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Thời gian: ${_timeFormat.format(DateTime.now())}',
                style: const TextStyle(color: Colors.white54, fontSize: 12),
              ),
              const SizedBox(height: 18),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF16254E),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white12),
                ),
                child: Column(
                  children: [
                    _buildModalRow('Người tham dự', ticket.customerName ?? 'Khách hàng', isBold: true),
                    const Divider(color: Colors.white10, height: 16),
                    _buildModalRow('Mã vé', ticket.ticketCode, isMono: true),
                    const Divider(color: Colors.white10, height: 16),
                    _buildModalRow('Hạng vé', ticket.ticketType ?? 'Vé tham dự'),
                    if (ticket.seatName != null && ticket.seatName!.isNotEmpty) ...[
                      const Divider(color: Colors.white10, height: 16),
                      _buildModalRow('Ghế ngồi', ticket.seatName!, highlight: true),
                    ],
                    if (_selectedEvent?['gate'] != null) ...[
                      const Divider(color: Colors.white10, height: 16),
                      _buildModalRow('Cổng soát', _selectedEvent!['gate'].toString()),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 46,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(ctx),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryContainer,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('XONG / TIẾP TỤC', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showTicketDetailModal(TicketModel ticket) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0F1A36),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        final isCheckedIn = ticket.isUsed;
        return SafeArea(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(ctx).size.height * 0.85,
            ),
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 16,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 44,
                      height: 5,
                      decoration: BoxDecoration(
                        color: Colors.white24,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Expanded(
                        child: Text(
                          'Chi Tiết Vé Soát',
                          softWrap: true,
                          style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: isCheckedIn ? Colors.green.withValues(alpha: 0.15) : AppColors.primaryContainer.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: isCheckedIn ? Colors.greenAccent : AppColors.primaryContainer,
                            width: 1,
                          ),
                        ),
                        child: Text(
                          isCheckedIn ? 'ĐÃ CHECK-IN' : 'HỢP LỆ / CHƯA CHECK-IN',
                          softWrap: true,
                          style: TextStyle(
                            color: isCheckedIn ? Colors.greenAccent : AppColors.primaryContainer,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFF16254E),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white10),
                    ),
                    child: Column(
                      children: [
                        _buildModalRow('Họ & tên', ticket.customerName ?? 'Khách hàng', isBold: true),
                        const Divider(color: Colors.white10, height: 14),
                        _buildModalRow('Email', ticket.customerEmail ?? 'Chưa có thông tin'),
                        if (ticket.attendeePhone != null && ticket.attendeePhone!.isNotEmpty) ...[
                          const Divider(color: Colors.white10, height: 14),
                          _buildModalRow('Điện thoại', ticket.attendeePhone!),
                        ],
                        const Divider(color: Colors.white10, height: 14),
                        _buildModalRow('Mã vé', ticket.ticketCode, isMono: true),
                        const Divider(color: Colors.white10, height: 14),
                        _buildModalRow('Hạng vé', ticket.ticketType ?? 'Vé tham dự'),
                        if (ticket.seatName != null && ticket.seatName!.isNotEmpty) ...[
                          const Divider(color: Colors.white10, height: 14),
                          _buildModalRow('Khu vực / Ghế', ticket.seatName!, highlight: true),
                        ],
                        if (ticket.checkInTime != null) ...[
                          const Divider(color: Colors.white10, height: 14),
                          _buildModalRow('Thời gian check-in', _formatCheckinTime(ticket.checkInTime!)),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  if (!isCheckedIn) ...[
                    SizedBox(
                      width: double.infinity,
                      height: 46,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.pop(ctx);
                          _handleManualCheckIn(ticket);
                        },
                        icon: const Icon(Icons.how_to_reg, color: Colors.white, size: 20),
                        label: const Text(
                          'XÁC NHẬN CHECK-IN TAY',
                          softWrap: true,
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green[600],
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                  ] else ...[
                    SizedBox(
                      width: double.infinity,
                      height: 46,
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(ctx),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Colors.white24),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: const Text('ĐÓNG', style: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _showEventPickerSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0F1A36),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 48,
                  height: 5,
                  decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(3)),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Chọn Sự Kiện Được Phân Công',
                style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              const Text(
                'Chỉ hiển thị danh sách người tham dự của sự kiện được chọn',
                style: TextStyle(color: Colors.white54, fontSize: 12),
              ),
              const SizedBox(height: 16),
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: _assignedEvents.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (_, idx) {
                    final ev = _assignedEvents[idx];
                    final isSelected = ev['id'] == _selectedEvent?['id'];
                    return ListTile(
                      tileColor: isSelected ? AppColors.primaryContainer.withValues(alpha: 0.15) : const Color(0xFF16254E),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(
                          color: isSelected ? AppColors.primaryContainer : Colors.white10,
                          width: isSelected ? 1.5 : 1,
                        ),
                      ),
                      leading: Icon(
                        Icons.event_available_rounded,
                        color: isSelected ? AppColors.primaryContainer : AppColors.secondary,
                      ),
                      title: Text(
                        ev['title']?.toString() ?? 'Sự kiện',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          fontSize: 14,
                        ),
                      ),
                      subtitle: Text(
                        'Vai trò: ${ev['staff_role'] ?? 'Nhân viên'}${ev['gate'] != null ? ' • Cổng: ${ev['gate']}' : ''}${ev['zone'] != null ? ' • Khu: ${ev['zone']}' : ''}',
                        style: const TextStyle(color: Colors.white54, fontSize: 11),
                      ),
                      trailing: isSelected ? const Icon(Icons.check_circle, color: AppColors.primaryContainer, size: 20) : null,
                      onTap: () {
                        Navigator.pop(ctx);
                        _onEventSelected(ev);
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
  }

  void _showAdvancedFilterSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0F1A36),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 48,
                  height: 5,
                  decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(3)),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Bộ Lọc Chi Tiết', style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold)),
                  TextButton(
                    onPressed: () {
                      _ticketCodeController.clear();
                      _buyerNameController.clear();
                      _buyerEmailController.clear();
                      _buyerPhoneController.clear();
                      Navigator.pop(ctx);
                      _fetchTicketsForSelectedEvent();
                    },
                    child: const Text('Đặt lại', style: TextStyle(color: Colors.redAccent, fontSize: 13)),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _buildFilterInputField('Mã vé', _ticketCodeController, Icons.qr_code),
              const SizedBox(height: 10),
              _buildFilterInputField('Tên người mua / tham dự', _buyerNameController, Icons.person_outline),
              const SizedBox(height: 10),
              _buildFilterInputField('Email người mua', _buyerEmailController, Icons.email_outlined),
              const SizedBox(height: 10),
              _buildFilterInputField('Số điện thoại', _buyerPhoneController, Icons.phone_outlined),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 46,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(ctx);
                    _fetchTicketsForSelectedEvent();
                  },
                  icon: const Icon(Icons.search, color: Colors.white, size: 18),
                  label: const Text('ÁP DỤNG BỘ LỌC', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryContainer,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildFilterInputField(String label, TextEditingController controller, IconData icon) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF16254E),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white12),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: TextField(
        controller: controller,
        style: const TextStyle(color: Colors.white, fontSize: 13),
        decoration: InputDecoration(
          icon: Icon(icon, color: Colors.white54, size: 18),
          labelText: label,
          labelStyle: const TextStyle(color: Colors.white54, fontSize: 12),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 8),
        ),
      ),
    );
  }

  List<TicketModel> get _filteredTickets {
    if (_activeStatusFilter == 'valid') {
      return _tickets.where((t) => !t.isUsed).toList();
    } else if (_activeStatusFilter == 'used') {
      return _tickets.where((t) => t.isUsed).toList();
    }
    return _tickets;
  }

  int get _validCount => _tickets.where((t) => !t.isUsed).length;
  int get _usedCount => _tickets.where((t) => t.isUsed).length;

  Widget _buildModalRow(String label, String value, {bool isBold = false, bool isMono = false, bool highlight = false}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Flexible(
          flex: 2,
          child: Text(
            label,
            style: const TextStyle(color: Colors.white54, fontSize: 12),
            softWrap: true,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          flex: 3,
          child: Text(
            value,
            textAlign: TextAlign.end,
            softWrap: true,
            style: TextStyle(
              color: highlight
                  ? Colors.amberAccent
                  : (isBold ? Colors.white : Colors.white70),
              fontWeight: isBold ? FontWeight.bold : FontWeight.w500,
              fontFamily: isMono ? 'monospace' : null,
              fontSize: 12,
            ),
          ),
        ),
      ],
    );
  }

  String _formatCheckinTime(String timeStr) {
    final parsed = DateTime.tryParse(timeStr);
    if (parsed != null) {
      return _dateTimeFormat.format(parsed.toLocal());
    }
    return timeStr;
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
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Soát Vé Thủ Công & Người Tham Dự',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
            ),
            Text(
              'Check-in trực tiếp theo danh sách sự kiện',
              style: TextStyle(color: Colors.white54, fontSize: 11),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white70),
            tooltip: 'Tải lại danh sách',
            onPressed: _fetchTicketsForSelectedEvent,
          ),
        ],
      ),
      body: _isLoadingEvents
          ? const Center(child: CircularProgressIndicator(color: AppColors.primaryContainer))
          : _eventsError != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.event_busy, color: Colors.orangeAccent, size: 54),
                        const SizedBox(height: 16),
                        Text(
                          _eventsError!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 20),
                        ElevatedButton(
                          onPressed: _loadAssignedEvents,
                          style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryContainer),
                          child: const Text('Thử lại', style: TextStyle(color: Colors.white)),
                        ),
                      ],
                    ),
                  ),
                )
              : Column(
                  children: [
                    // Event Selector Header Bar
                    _buildEventSelectorHeader(),

                    // Check-in Not-Open Notice
                    if (_checkinNotice != null) ...[
                      Container(
                        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.amber.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.amberAccent.withValues(alpha: 0.4)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.access_time_rounded, color: Colors.amberAccent, size: 24),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                _checkinNotice!,
                                style: const TextStyle(color: Colors.amberAccent, fontSize: 12, height: 1.4),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    // Search & Filters Bar
                    _buildSearchBar(),

                    // Status Tabs (All, Valid, Used)
                    _buildStatusTabs(),

                    // Tickets List
                    Expanded(
                      child: RefreshIndicator(
                        color: AppColors.primaryContainer,
                        backgroundColor: const Color(0xFF0C1446),
                        onRefresh: _fetchTicketsForSelectedEvent,
                        child: _buildTicketsList(),
                      ),
                    ),
                  ],
                ),
    );
  }

  Widget _buildEventSelectorHeader() {
    final event = _selectedEvent;
    final title = event?['title']?.toString() ?? 'Chưa chọn sự kiện';
    final role = event?['staff_role']?.toString() ?? 'Nhân sự';
    final gate = event?['gate']?.toString();
    final zone = event?['zone']?.toString();

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      decoration: const BoxDecoration(
        color: Color(0xFF0C1446),
        border: Border(bottom: BorderSide(color: Colors.white10)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.event, color: AppColors.primaryContainer, size: 16),
                        SizedBox(width: 6),
                        Text(
                          'SỰ KIỆN ĐANG CHỌN',
                          style: TextStyle(
                            color: AppColors.primaryContainer,
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      title,
                      softWrap: true,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                  ],
                ),
              ),
              if (_assignedEvents.length > 1)
                InkWell(
                  onTap: _showEventPickerSheet,
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF16254E),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.white12),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.swap_horiz, color: AppColors.secondary, size: 16),
                        SizedBox(width: 4),
                        Text(
                          'Đổi sự kiện',
                          style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _buildBadge(role, const Color(0xFF0284C7)),
              if (gate != null && gate.isNotEmpty)
                _buildBadge('Cổng: $gate', const Color(0xFF7C3AED)),
              if (zone != null && zone.isNotEmpty)
                _buildBadge('Khu vực: $zone', const Color(0xFF4F46E5)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBadge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Text(
        label,
        style: TextStyle(color: color.withValues(alpha: 0.95), fontSize: 10, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      color: const Color(0xFF081126),
      child: Row(
        children: [
          Expanded(
            child: Container(
              height: 44,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: const Color(0xFF0C1446),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.search, color: AppColors.secondary, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                      onChanged: _onSearchChanged,
                      decoration: const InputDecoration(
                        hintText: 'Tìm theo tên, mã vé, email, SĐT...',
                        hintStyle: TextStyle(color: Colors.white38, fontSize: 12),
                        border: InputBorder.none,
                        isDense: true,
                      ),
                    ),
                  ),
                  if (_searchController.text.isNotEmpty)
                    GestureDetector(
                      onTap: () {
                        _searchController.clear();
                        _fetchTicketsForSelectedEvent();
                      },
                      child: const Icon(Icons.clear, color: Colors.white54, size: 16),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          InkWell(
            onTap: _showAdvancedFilterSheet,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              height: 44,
              width: 44,
              decoration: BoxDecoration(
                color: const Color(0xFF0C1446),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white12),
              ),
              child: const Icon(Icons.tune, color: AppColors.secondary, size: 20),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusTabs() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        children: [
          _buildFilterChip('Tất cả (${_tickets.length})', 'all'),
          const SizedBox(width: 8),
          _buildFilterChip('Chưa soát ($_validCount)', 'valid'),
          const SizedBox(width: 8),
          _buildFilterChip('Đã soát ($_usedCount)', 'used'),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, String value) {
    final isSelected = _activeStatusFilter == value;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _activeStatusFilter = value),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.primaryContainer : const Color(0xFF0C1446),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected ? AppColors.primaryContainer : Colors.white10,
            ),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: isSelected ? Colors.white : Colors.white70,
              fontSize: 11,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTicketsList() {
    if (_isLoadingTickets) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primaryContainer),
      );
    }

    if (_ticketsError != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, color: AppColors.error, size: 48),
              const SizedBox(height: 12),
              Text(
                _ticketsError!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white, fontSize: 13),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _fetchTicketsForSelectedEvent,
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryContainer),
                child: const Text('Thử lại', style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        ),
      );
    }

    final displayTickets = _filteredTickets;

    if (displayTickets.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.people_alt_outlined,
                color: Colors.white24,
                size: 56,
              ),
              SizedBox(height: 14),
              Text(
                'Không tìm thấy người tham dự phù hợp',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
              ),
              SizedBox(height: 6),
              Text(
                'Thử tìm với từ khoá khác hoặc đổi sang sự kiện khác.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white38, fontSize: 12),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 24),
      itemCount: displayTickets.length,
      itemBuilder: (ctx, idx) {
        final item = displayTickets[idx];
        final isCheckedIn = item.isUsed;
        final isCheckingIn = _checkingInTicketIds.contains(item.ticketId);

        return Card(
          margin: const EdgeInsets.only(bottom: 10),
          color: const Color(0xFF0C1446),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: BorderSide(
              color: isCheckedIn ? Colors.greenAccent.withValues(alpha: 0.2) : Colors.white10,
            ),
          ),
          child: InkWell(
            onTap: () => _showTicketDetailModal(item),
            borderRadius: BorderRadius.circular(14),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: isCheckedIn ? Colors.green.withValues(alpha: 0.15) : const Color(0xFF16254E),
                    child: Text(
                      item.customerName?.isNotEmpty == true ? item.customerName![0].toUpperCase() : 'U',
                      style: TextStyle(
                        color: isCheckedIn ? Colors.greenAccent : Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.customerName ?? 'Khách hàng',
                          softWrap: true,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${item.ticketType ?? 'Vé tham dự'} • ${item.seatName ?? 'Khu tự do'}',
                          softWrap: true,
                          style: const TextStyle(color: AppColors.secondary, fontSize: 11),
                        ),
                        const SizedBox(height: 1),
                        Text(
                          item.ticketCode,
                          style: const TextStyle(
                            color: AppColors.primaryContainer,
                            fontSize: 11,
                            fontFamily: 'monospace',
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (isCheckedIn) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.green.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.greenAccent.withValues(alpha: 0.3)),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.check, color: Colors.greenAccent, size: 12),
                          SizedBox(width: 4),
                          Text(
                            'ĐÃ SOÁT',
                            style: TextStyle(
                              color: Colors.greenAccent,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ] else ...[
                    ElevatedButton(
                      onPressed: isCheckingIn ? null : () => _handleManualCheckIn(item),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryContainer,
                        minimumSize: const Size(82, 34),
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      child: isCheckingIn
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Text(
                              'Check-in',
                              style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                            ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
