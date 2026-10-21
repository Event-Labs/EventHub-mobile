import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/api/auth_service.dart';
import '../../../../core/api/events_service.dart';
import '../../../../core/api/staff_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../home/presentation/pages/payment_page.dart';
import '../../../home/presentation/pages/ticket_booking_page.dart';

class StaffDirectBookingPage extends StatefulWidget {
  final Map<String, dynamic>? initialEvent;

  const StaffDirectBookingPage({
    super.key,
    this.initialEvent,
  });

  @override
  State<StaffDirectBookingPage> createState() => _StaffDirectBookingPageState();
}

class _StaffDirectBookingPageState extends State<StaffDirectBookingPage> {
  final _formKey = GlobalKey<FormState>();
  final _buyerNameController = TextEditingController();
  final _buyerPhoneController = TextEditingController();
  final _buyerEmailController = TextEditingController();
  final _internalNoteController = TextEditingController();

  List<Map<String, dynamic>> _events = [];
  Map<String, dynamic>? _selectedEvent;
  Map<String, dynamic>? _selectedSession;
  bool _isLoadingEvents = true;
  bool _isSubmitting = false;

  // Seat map state for seated events
  bool _isLoadingSeats = false;
  bool _hasSeatMap = false;
  Map<String, dynamic>? _seatMapData;
  List<SessionSeatItem> _sessionSeats = [];
  final Set<String> _selectedSeatIds = {};
  final List<SessionSeatItem> _selectedSeats = [];
  final TransformationController _seatMapController = TransformationController();
  bool _hasFittedSeatMap = false;
  double _fitScale = 1.0;
  Matrix4? _lastFitMatrix;
  Size? _lastViewportSize;

  // Selected ticket quantities for non-seated ticket types: ticketTypeId -> quantity
  final Map<String, int> _selectedQuantities = {};
  String _paymentMethod = 'cash'; // 'cash' or 'bank_transfer'

  final _currencyFormat = NumberFormat.currency(locale: 'vi_VN', symbol: 'đ', decimalDigits: 0);

  @override
  void initState() {
    super.initState();
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
        Navigator.of(context).pop();
      });
      return;
    }
    _loadEvents();
  }

  @override
  void dispose() {
    _seatMapController.dispose();
    _buyerNameController.dispose();
    _buyerPhoneController.dispose();
    _buyerEmailController.dispose();
    _internalNoteController.dispose();
    super.dispose();
  }

  Future<void> _loadEvents() async {
    setState(() => _isLoadingEvents = true);
    try {
      // 1. First attempt: fetch events configured specifically for Direct Booking POS
      var events = await StaffService().getDirectBookingEvents();

      // 2. If direct booking specific list is empty, check assigned events from /operations/staff/events
      if (events.isEmpty) {
        final assigned = await StaffService().getAssignedEvents();
        if (assigned.isNotEmpty) {
          final realEvents = <Map<String, dynamic>>[];
          for (final aEvt in assigned) {
            final evtId = aEvt['id']?.toString() ?? '';
            var tTypes = aEvt['ticket_types'] ?? aEvt['ticketTypes'];
            var sessions = aEvt['sessions'];
            if ((tTypes == null || (tTypes is List && tTypes.isEmpty) || sessions == null || (sessions is List && sessions.isEmpty)) && evtId.isNotEmpty) {
              try {
                final detail = await EventsService().getEventDetail(evtId);
                if (detail.ticketTypes.isNotEmpty) {
                  tTypes = detail.ticketTypes.map((t) => {
                    'id': t.id,
                    'name': t.name,
                    'price': t.price,
                    'available_quantity': t.availableQuantity,
                    'remaining_quantity': t.availableQuantity,
                    'description': t.description,
                  }).toList();
                }
                if (detail.sessions.isNotEmpty) {
                  sessions = detail.sessions.map((s) => {
                    'id': s.id,
                    'session_name': s.name ?? 'Suất diễn',
                    'start_time': s.startTime,
                    'end_time': s.endTime,
                    'venue': s.venue != null ? {
                      'name': s.venue!.name,
                      'address_line': s.venue!.addressLine,
                      'district': s.venue!.district,
                      'city': s.venue!.city,
                      'summary': s.venue!.summary,
                    } : null,
                  }).toList();
                }
              } catch (_) {}
            }
            final map = Map<String, dynamic>.from(aEvt);
            if (tTypes != null) map['ticket_types'] = tTypes;
            if (sessions != null) map['sessions'] = sessions;
            realEvents.add(map);
          }
          events = realEvents;
        }
      }

      _events = events;
    } catch (_) {
      _events = [];
    }

    if (widget.initialEvent != null) {
      final initialId = widget.initialEvent!['id']?.toString();
      final match = _events.where((e) => e['id']?.toString() == initialId || (initialId == null && e['title'] == widget.initialEvent!['title'])).firstOrNull;
      if (match != null) {
        _selectedEvent = match;
      } else if (_events.isNotEmpty) {
        _selectedEvent = _events.first;
      } else {
        _selectedEvent = null;
      }
    } else if (_events.isNotEmpty) {
      _selectedEvent = _events.first;
    } else {
      _selectedEvent = null;
    }

    await _onEventSelected(_selectedEvent);

    if (mounted) {
      setState(() => _isLoadingEvents = false);
    }
  }

  Future<void> _onEventSelected(Map<String, dynamic>? event) async {
    _selectedEvent = event;
    if (_selectedEvent != null) {
      // Check if sessions list is empty, enrich from getEventDetail if needed
      final existingSessions = _getSessions();
      if (existingSessions.isEmpty) {
        final eventId = _selectedEvent!['id']?.toString() ?? '';
        if (eventId.isNotEmpty) {
          try {
            final detail = await EventsService().getEventDetail(eventId);
            if (detail.sessions.isNotEmpty) {
              _selectedEvent!['sessions'] = detail.sessions.map((s) => {
                'id': s.id,
                'session_name': s.name ?? 'Suất diễn',
                'start_time': s.startTime,
                'end_time': s.endTime,
                'venue': s.venue != null ? {
                  'name': s.venue!.name,
                  'address_line': s.venue!.addressLine,
                  'district': s.venue!.district,
                  'city': s.venue!.city,
                  'summary': s.venue!.summary,
                } : null,
              }).toList();
            }
            final curTicketTypes = _selectedEvent!['ticket_types'] ?? _selectedEvent!['ticketTypes'];
            if ((curTicketTypes == null || (curTicketTypes is List && curTicketTypes.isEmpty)) &&
                detail.ticketTypes.isNotEmpty) {
              _selectedEvent!['ticket_types'] = detail.ticketTypes.map((t) => {
                'id': t.id,
                'name': t.name,
                'price': t.price,
                'available_quantity': t.availableQuantity,
                'remaining_quantity': t.availableQuantity,
                'description': t.description,
              }).toList();
            }
          } catch (_) {}
        }
      }

      final sessions = _getSessions();
      _selectedSession = sessions.isNotEmpty ? sessions.first : null;
    } else {
      _selectedSession = null;
    }

    _resetTicketQuantities();

    final sessId = _selectedSession?['id']?.toString();
    await _loadSessionSeats(sessId);
  }

  void _resetTicketQuantities() {
    _selectedQuantities.clear();
    _selectedSeatIds.clear();
    _selectedSeats.clear();
    final ticketTypes = _getCurrentTicketTypes();
    for (final tt in ticketTypes) {
      final id = tt['id']?.toString() ?? '';
      if (id.isNotEmpty) {
        _selectedQuantities[id] = 0;
      }
    }
  }

  List<Map<String, dynamic>> _getSessions() {
    if (_selectedEvent == null) return [];
    final sessions = _selectedEvent!['sessions'];
    if (sessions is List && sessions.isNotEmpty) {
      return sessions.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
    }
    return [];
  }

  List<Map<String, dynamic>> _getCurrentTicketTypes() {
    if (_selectedEvent == null) return [];
    final list = _selectedEvent!['ticket_types'] ?? _selectedEvent!['ticketTypes'];
    if (list is! List || list.isEmpty) return [];
    final allTypes = list.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
    if (_selectedSession == null) return allTypes;
    final sessId = _selectedSession!['id']?.toString();
    if (sessId == null || sessId.isEmpty) return allTypes;

    final filtered = allTypes.where((tt) {
      final tSessId = tt['event_session_id']?.toString();
      return tSessId == null || tSessId.isEmpty || tSessId == sessId;
    }).toList();

    return filtered.isNotEmpty ? filtered : allTypes;
  }

  Future<void> _loadSessionSeats(String? sessionId) async {
    if (sessionId == null || sessionId.isEmpty) {
      if (mounted) {
        setState(() {
          _isLoadingSeats = false;
          _hasSeatMap = false;
          _sessionSeats = [];
          _seatMapData = null;
          _selectedSeatIds.clear();
          _selectedSeats.clear();
        });
      }
      return;
    }

    setState(() {
      _isLoadingSeats = true;
      _selectedSeatIds.clear();
      _selectedSeats.clear();
      _hasFittedSeatMap = false;
      _lastFitMatrix = null;
    });

    try {
      final data = await EventsService().getSessionSeats(sessionId);
      if (!mounted) return;
      final rawSeats = (data['seats'] as List?) ?? [];
      final List<SessionSeatItem> seats = rawSeats
          .map((s) => SessionSeatItem.fromJson(s as Map<String, dynamic>))
          .toList();

      setState(() {
        _isLoadingSeats = false;
        _seatMapData = data['seat_map'] as Map<String, dynamic>?;
        _sessionSeats = seats;
        _hasSeatMap = seats.isNotEmpty;
        _hasFittedSeatMap = false;
        _lastFitMatrix = null;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _isLoadingSeats = false;
          _hasSeatMap = false;
          _sessionSeats = [];
          _seatMapData = null;
        });
      }
    }
  }

  Map<String, dynamic>? _getTicketTypeForSeat(SessionSeatItem seat) {
    final currentTypes = _getCurrentTicketTypes();
    if (seat.ticketTypeIds.isNotEmpty) {
      for (final tid in seat.ticketTypeIds) {
        for (final t in currentTypes) {
          if (t['id']?.toString() == tid) return t;
        }
      }
    }
    if (seat.zoneName != null && seat.zoneName!.isNotEmpty) {
      final zNameLower = seat.zoneName!.trim().toLowerCase();
      for (final t in currentTypes) {
        if ((t['name']?.toString() ?? '').trim().toLowerCase() == zNameLower) {
          return t;
        }
      }
    }
    return currentTypes.isNotEmpty ? currentTypes.first : null;
  }

  Color _getSeatColor(SessionSeatItem seat) {
    if (seat.zoneColor != null) return seat.zoneColor!;
    final tt = _getTicketTypeForSeat(seat);
    if (tt != null) {
      final palette = [
        const Color(0xFFF59E0B), // Amber
        const Color(0xFF3B82F6), // Blue
        const Color(0xFF10B981), // Emerald
        const Color(0xFFA855F7), // Purple
        const Color(0xFFEC4899), // Pink
        const Color(0xFF06B6D4), // Cyan
      ];
      final types = _getCurrentTicketTypes();
      final idx = types.indexWhere((t) => t['id']?.toString() == tt['id']?.toString());
      if (idx >= 0) return palette[idx % palette.length];
    }
    return const Color(0xFF06B6D4);
  }

  void _toggleSeat(SessionSeatItem seat) {
    if (!seat.isAvailable && !_selectedSeatIds.contains(seat.sessionSeatId)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Ghế ${seat.label} hiện không khả dụng (đã bán hoặc đang được giữ).'),
          duration: const Duration(seconds: 1),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() {
      if (_selectedSeatIds.contains(seat.sessionSeatId)) {
        _selectedSeatIds.remove(seat.sessionSeatId);
        _selectedSeats.removeWhere((s) => s.sessionSeatId == seat.sessionSeatId);
      } else {
        if (_selectedSeatIds.length >= 10) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Tối đa 10 ghế trong một lần bán vé tại quầy.'),
              backgroundColor: AppColors.error,
            ),
          );
          return;
        }
        _selectedSeatIds.add(seat.sessionSeatId);
        _selectedSeats.add(seat);
      }
    });
  }

  void _zoomIn() => _zoomBy(1.3);
  void _zoomOut() => _zoomBy(0.77);
  void _resetZoom() {
    if (_lastFitMatrix != null) {
      _seatMapController.value = _lastFitMatrix!.clone();
    } else {
      _seatMapController.value = Matrix4.identity();
    }
  }

  void _zoomBy(double factor) {
    final viewportSize = _lastViewportSize ?? const Size(360, 400);
    final cx = viewportSize.width / 2;
    final cy = viewportSize.height / 2;

    final current = _seatMapController.value;
    final currentScale = current.getMaxScaleOnAxis();
    final minScale = min(0.05, _fitScale * 0.7);
    const maxScale = 4.5;

    final targetScale = (currentScale * factor).clamp(minScale, maxScale);
    final actualFactor = targetScale / currentScale;
    if ((actualFactor - 1.0).abs() < 0.001) return;

    final translation = current.getTranslation();
    final newTx = cx - actualFactor * (cx - translation.x);
    final newTy = cy - actualFactor * (cy - translation.y);

    // ignore: deprecated_member_use
    final matrix = Matrix4.identity()
      // ignore: deprecated_member_use
      ..translate(newTx, newTy)
      // ignore: deprecated_member_use
      ..scale(targetScale, targetScale, 1.0);

    _seatMapController.value = matrix;
  }

  int get _totalTicketsCount {
    int count = 0;
    if (_hasSeatMap) {
      count += _selectedSeatIds.length;
    }
    final currentTypes = _getCurrentTicketTypes();
    for (final tt in currentTypes) {
      final isSeated = tt['is_seated'] == true || tt['is_seated'] == 1 || tt['is_seated'] == 'true';
      if (!_hasSeatMap || !isSeated) {
        final id = tt['id']?.toString() ?? '';
        count += _selectedQuantities[id] ?? 0;
      }
    }
    return count;
  }

  double get _totalPrice {
    double total = 0;
    if (_hasSeatMap && _selectedSeats.isNotEmpty) {
      for (final seat in _selectedSeats) {
        final tt = _getTicketTypeForSeat(seat);
        if (tt != null) {
          final price = double.tryParse(tt['price']?.toString() ?? '0') ?? 0;
          total += price;
        }
      }
    }
    final currentTypes = _getCurrentTicketTypes();
    for (final tt in currentTypes) {
      final isSeated = tt['is_seated'] == true || tt['is_seated'] == 1 || tt['is_seated'] == 'true';
      if (!_hasSeatMap || !isSeated) {
        final id = tt['id']?.toString() ?? '';
        final qty = _selectedQuantities[id] ?? 0;
        final price = double.tryParse(tt['price']?.toString() ?? '0') ?? 0;
        total += price * qty;
      }
    }
    return total;
  }

  String _formatSessionTime(dynamic startStr, dynamic endStr) {
    if (startStr == null) return 'Chưa cập nhật';
    try {
      final start = DateTime.parse(startStr.toString()).toLocal();
      final startFormatted = DateFormat('HH:mm').format(start);
      if (endStr != null) {
        final end = DateTime.parse(endStr.toString()).toLocal();
        final endFormatted = DateFormat('HH:mm').format(end);
        return '$startFormatted - $endFormatted';
      }
      return startFormatted;
    } catch (_) {
      return startStr.toString();
    }
  }

  String _formatShortDate(dynamic dateStr) {
    if (dateStr == null) return 'Chưa cập nhật';
    try {
      final d = DateTime.parse(dateStr.toString()).toLocal();
      final weekdays = [
        'Thứ Hai',
        'Thứ Ba',
        'Thứ Tư',
        'Thứ Năm',
        'Thứ Sáu',
        'Thứ Bảy',
        'Chủ Nhật'
      ];
      final weekdayName = weekdays[d.weekday - 1];
      return '$weekdayName, ${DateFormat('dd/MM/yyyy').format(d)}';
    } catch (_) {
      return dateStr.toString();
    }
  }

  void _showEventPicker() {
    if (_events.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Không có sự kiện nào khác được phân công cho bạn.'),
          backgroundColor: AppColors.secondary,
        ),
      );
      return;
    }
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF0C1446),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.75),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.event, color: AppColors.primaryContainer),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text('Chọn Sự Kiện Bán Vé', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold), softWrap: true),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Flexible(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: _events.map((evt) {
                        final isSelected = _selectedEvent?['id'] == evt['id'];
                        return ListTile(
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          tileColor: isSelected ? AppColors.primaryContainer.withValues(alpha: 0.15) : Colors.transparent,
                          leading: Icon(
                            isSelected ? Icons.check_circle : Icons.festival_outlined,
                            color: isSelected ? AppColors.primaryContainer : AppColors.secondary,
                          ),
                          title: Text(
                            evt['title'] ?? evt['name'] ?? 'Sự kiện không tên',
                            softWrap: true,
                            style: TextStyle(
                              color: isSelected ? Colors.white : Colors.white70,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                            ),
                          ),
                          subtitle: Text(
                            evt['venue_name'] ?? evt['venue']?['name'] ?? '',
                            softWrap: true,
                            style: const TextStyle(color: AppColors.secondary, fontSize: 12),
                          ),
                          onTap: () {
                            Navigator.pop(ctx);
                            setState(() {
                              _selectedEvent = evt;
                            });
                            _onEventSelected(evt);
                          },
                        );
                      }).toList(),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showSessionPicker() {
    final sessions = _getSessions();
    if (sessions.length <= 1) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF0C1446),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.75),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.calendar_month_outlined, color: AppColors.primaryContainer),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text('Chọn Suất Diễn', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold), softWrap: true),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Flexible(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: sessions.map((sess) {
                        final isSelected = _selectedSession?['id'] == sess['id'];
                        final sName = sess['session_name'] ?? 'Suất diễn';
                        final sTime = _formatSessionTime(sess['start_time'], sess['end_time']);
                        final sDate = _formatShortDate(sess['start_time']);

                        return ListTile(
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          tileColor: isSelected ? AppColors.primaryContainer.withValues(alpha: 0.15) : Colors.transparent,
                          leading: Icon(
                            isSelected ? Icons.check_circle : Icons.schedule,
                            color: isSelected ? AppColors.primaryContainer : AppColors.secondary,
                          ),
                          title: Text(
                            sName,
                            softWrap: true,
                            style: TextStyle(
                              color: isSelected ? Colors.white : Colors.white70,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                            ),
                          ),
                          subtitle: Text(
                            '$sTime • $sDate',
                            softWrap: true,
                            style: const TextStyle(color: AppColors.secondary, fontSize: 12),
                          ),
                          onTap: () {
                            Navigator.pop(ctx);
                            if (_selectedSession?['id'] != sess['id']) {
                              setState(() {
                                _selectedSession = sess;
                                _resetTicketQuantities();
                              });
                              _loadSessionSeats(sess['id']?.toString());
                            }
                          },
                        );
                      }).toList(),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _handleDirectBooking() async {
    if (!_formKey.currentState!.validate()) return;

    if (_totalTicketsCount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vui lòng chọn ít nhất 1 vé hoặc ghế để bán!'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    final eventId = _selectedEvent?['id']?.toString();
    if (eventId == null || eventId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Chưa chọn sự kiện!'), backgroundColor: AppColors.error),
      );
      return;
    }

    final phone = _buyerPhoneController.text.trim();
    final phoneRegex = RegExp(r'^(0|\+84)(3|5|7|8|9)[0-9]{8}$');
    if (!phoneRegex.hasMatch(phone)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Số điện thoại không đúng định dạng (VD: 0912345678).'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    final items = <Map<String, dynamic>>[];
    if (_hasSeatMap && _selectedSeats.isNotEmpty) {
      final Map<String, List<String>> seatsByType = {};
      for (final seat in _selectedSeats) {
        final tt = _getTicketTypeForSeat(seat);
        final tid = tt?['id']?.toString();
        if (tid != null && tid.isNotEmpty) {
          seatsByType.putIfAbsent(tid, () => []).add(seat.sessionSeatId);
        }
      }
      seatsByType.forEach((typeId, seatIds) {
        items.add({
          'ticket_type_id': typeId,
          'quantity': seatIds.length,
          'session_seat_ids': seatIds,
        });
      });
    }

    // Add unseated items
    final currentTypes = _getCurrentTicketTypes();
    for (final tt in currentTypes) {
      final isSeated = tt['is_seated'] == true || tt['is_seated'] == 1 || tt['is_seated'] == 'true';
      if (!_hasSeatMap || !isSeated) {
        final typeId = tt['id']?.toString() ?? '';
        final qty = _selectedQuantities[typeId] ?? 0;
        if (qty > 0) {
          items.add({
            'ticket_type_id': typeId,
            'quantity': qty,
            'session_seat_ids': <String>[],
          });
        }
      }
    }

    if (items.isEmpty) {
      setState(() => _isSubmitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vui lòng chọn ít nhất 1 vé hoặc ghế để bán!'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    final res = await StaffService().createDirectBooking(
      eventId: eventId,
      buyerName: _buyerNameController.text.trim(),
      buyerPhone: phone,
      buyerEmail: _buyerEmailController.text.trim(),
      internalNote: _internalNoteController.text.trim(),
      paymentMethod: _paymentMethod,
      items: items,
    );

    if (!mounted) return;
    setState(() => _isSubmitting = false);

    if (res['success'] == true && res['data'] != null) {
      final data = Map<String, dynamic>.from(res['data'] as Map);
      final status = data['order']?['status']?.toString().toUpperCase();

      if (_paymentMethod == 'bank_transfer' && status == 'PENDING') {
        _showPayosPaymentDialog(data);
      } else {
        _showSuccessDialog(data);
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(res['message'] ?? 'Không thể tạo đơn đặt vé trực tiếp.'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  Future<void> _showPayosPaymentDialog(Map<String, dynamic> data) async {
    final updatedData = await showDialog<Map<String, dynamic>>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _StaffPayosPaymentDialog(
        initialData: data,
      ),
    );

    if (updatedData != null && mounted) {
      _showSuccessDialog(updatedData);
    }
  }

  void _showSuccessDialog(Map<String, dynamic> data) {
    final order = data['order'] is Map ? data['order'] as Map : data;
    final orderCode = order['order_code'] ?? data['order_code'] ?? data['orderCode'] ?? 'ORD-POS-SUCCESS';
    final List tickets = (data['tickets'] is List ? data['tickets'] : order['tickets'] is List ? order['tickets'] : []) as List;
    final firstTicketCode = tickets.isNotEmpty ? (tickets[0]['ticket_code'] ?? tickets[0]['code'] ?? orderCode) : orderCode;
    final buyerName = order['buyer_name'] ?? _buyerNameController.text.trim();
    final buyerPhone = order['buyer_phone'] ?? _buyerPhoneController.text.trim();
    final totalAmount = order['total_amount'] != null
        ? _currencyFormat.format(order['total_amount'])
        : _currencyFormat.format(_totalPrice);
    final seatLabels = _selectedSeats.map((s) => s.label).join(', ');

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Dialog(
        backgroundColor: const Color(0xFF0C1446),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: const BorderSide(color: Color(0xFF22C55E), width: 1.5),
        ),
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: const Color(0xFF22C55E).withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                    border: Border.all(color: const Color(0xFF22C55E), width: 2),
                  ),
                  child: const Icon(Icons.check_circle_rounded, color: Color(0xFF22C55E), size: 36),
                ),
                const SizedBox(height: 12),
                const Text(
                  'BÁN VÉ THÀNH CÔNG!',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
                ),
                const SizedBox(height: 4),
                Text(
                  'Đơn hàng: $orderCode',
                  style: const TextStyle(color: AppColors.primaryContainer, fontWeight: FontWeight.bold, fontSize: 13, fontFamily: 'monospace'),
                ),
                const SizedBox(height: 16),
                // QR Code representation of the issued ticket
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: QrImageView(
                    data: firstTicketCode.toString(),
                    version: QrVersions.auto,
                    size: 160,
                    backgroundColor: Colors.white,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  firstTicketCode.toString(),
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15, fontFamily: 'monospace'),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF122155),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      _buildDialogRow('Khách mua', buyerName.toString()),
                      const Divider(color: Colors.white12, height: 12),
                      _buildDialogRow('Số điện thoại', buyerPhone.toString()),
                      const Divider(color: Colors.white12, height: 12),
                      _buildDialogRow('Số lượng vé', '$_totalTicketsCount vé'),
                      if (seatLabels.isNotEmpty) ...[
                        const Divider(color: Colors.white12, height: 12),
                        _buildDialogRow('Ghế ngồi', seatLabels, highlight: true),
                      ],
                      const Divider(color: Colors.white12, height: 12),
                      _buildDialogRow('Tổng tiền', totalAmount, highlight: true),
                      const Divider(color: Colors.white12, height: 12),
                      _buildDialogRow('Hình thức', _paymentMethod == 'cash' ? 'Tiền mặt (Đã thu)' : 'Chuyển khoản PayOS (Đã nhận)'),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          Navigator.pop(ctx);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Đã gửi thông tin vé qua SMS/Email cho khách!')),
                          );
                        },
                        icon: const Icon(Icons.share, size: 16, color: AppColors.secondary),
                        label: const Text('Chia Sẻ Vé', style: TextStyle(color: AppColors.secondary, fontSize: 12)),
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: AppColors.secondary.withValues(alpha: 0.3)),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.pop(ctx);
                          _buyerNameController.clear();
                          _buyerPhoneController.clear();
                          _buyerEmailController.clear();
                          _internalNoteController.clear();
                          setState(() {
                            _resetTicketQuantities();
                          });
                          // Refresh session seats after direct booking
                          final sessId = _selectedSession?['id']?.toString();
                          if (sessId != null) {
                            _loadSessionSeats(sessId);
                          }
                        },
                        icon: const Icon(Icons.add, size: 16, color: Colors.white),
                        label: const Text('Đơn Mới', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primaryContainer,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDialogRow(String label, String value, {bool highlight = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Flexible(
            flex: 2,
            child: Text(
              label,
              style: const TextStyle(color: AppColors.secondary, fontSize: 12),
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
                color: highlight ? const Color(0xFF22C55E) : Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: highlight ? 13 : 12,
              ),
            ),
          ),
        ],
      ),
    );
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
        title: const Row(
          children: [
            Icon(Icons.point_of_sale, color: AppColors.primaryContainer, size: 22),
            SizedBox(width: 8),
            Text('Bán Vé Tại Quầy', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
          ],
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 12, top: 10, bottom: 10),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFF22C55E).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFF22C55E).withValues(alpha: 0.3)),
            ),
            child: const Row(
              children: [
                CircleAvatar(radius: 3, backgroundColor: Color(0xFF22C55E)),
                SizedBox(width: 6),
                Text('QUẦY LIVE', style: TextStyle(color: Color(0xFF22C55E), fontSize: 10, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        ],
      ),
      body: _isLoadingEvents
          ? const Center(child: CircularProgressIndicator(color: AppColors.primaryContainer))
          : _events.isEmpty
              ? _buildNoEventsEmptyState()
              : Form(
                  key: _formKey,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Step 1: Selected Event Card
                        _buildSectionHeader('1. SỰ KIỆN ÁP DỤNG', Icons.festival_outlined),
                        const SizedBox(height: 8),
                        _buildEventCard(),

                        const SizedBox(height: 24),
                        // Step 2: Select Ticket Types & Seats / Layout Map
                        _buildSectionHeader(
                          _hasSeatMap ? '2. SƠ ĐỒ CHỌN GHẾ NGỒI' : '2. SƠ ĐỒ SỰ KIỆN & CHỌN VÉ',
                          _hasSeatMap ? Icons.event_seat_rounded : Icons.confirmation_number_outlined,
                        ),
                        const SizedBox(height: 8),
                        _buildTicketTypesList(),

                        const SizedBox(height: 24),
                        // Step 3: Customer Information
                        _buildSectionHeader('3. THÔNG TIN KHÁCH HÀNG', Icons.person_outline),
                        const SizedBox(height: 8),
                        _buildCustomerForm(),

                        const SizedBox(height: 24),
                        // Step 4: Payment Method
                        _buildSectionHeader('4. PHƯƠNG THỨC THANH TOÁN', Icons.payments_outlined),
                        const SizedBox(height: 8),
                        _buildPaymentMethodSelector(),

                        const SizedBox(height: 32),
                        // Summary & Submit Button
                        _buildCheckoutSummary(),
                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
                ),
    );
  }

  Widget _buildNoEventsEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: const Color(0xFF0C1446),
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.secondary.withValues(alpha: 0.3), width: 2),
              ),
              child: const Icon(Icons.event_busy, color: AppColors.secondary, size: 40),
            ),
            const SizedBox(height: 20),
            const Text(
              'Chưa Có Sự Kiện Được Phân Công',
              style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            const Text(
              'Bạn chỉ có thể bán vé tại quầy cho những sự kiện mà Ban tổ chức đã mời hoặc phân công bạn tham gia.',
              style: TextStyle(color: AppColors.secondary, fontSize: 13, height: 1.5),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _loadEvents,
              icon: const Icon(Icons.refresh, size: 18, color: Colors.white),
              label: const Text('Tải lại danh sách', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryContainer,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: AppColors.primaryContainer, size: 18),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            color: AppColors.secondary,
            fontSize: 12,
            fontWeight: FontWeight.bold,
            letterSpacing: 1,
          ),
        ),
      ],
    );
  }

  Widget _buildEventCard() {
    final title = _selectedEvent?['title'] ?? _selectedEvent?['name'] ?? 'Chưa chọn sự kiện';
    final venue = _selectedEvent?['venue_name'] ?? _selectedEvent?['venue']?['name'] ?? 'Địa điểm đang cập nhật';
    final sessions = _getSessions();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFF0C1446),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.secondary.withValues(alpha: 0.2)),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.primaryContainer.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.stadium, color: AppColors.primaryContainer, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                      softWrap: true,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      venue,
                      style: const TextStyle(color: AppColors.secondary, fontSize: 11),
                      softWrap: true,
                    ),
                  ],
                ),
              ),
              if (_events.length > 1) ...[
                const SizedBox(width: 8),
                OutlinedButton(
                  onPressed: _showEventPicker,
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppColors.primaryContainer),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  ),
                  child: const Text('ĐỔI', style: TextStyle(color: AppColors.primaryContainer, fontSize: 11, fontWeight: FontWeight.bold)),
                ),
              ],
            ],
          ),
        ),

        // Session Information Card
        if (_selectedSession != null) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF101932),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFC99A47).withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.calendar_month, color: Color(0xFFE6C17A), size: 18),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              _selectedSession!['session_name'] ?? 'Suất diễn',
                              softWrap: true,
                              style: const TextStyle(color: Color(0xFFE6C17A), fontSize: 12, fontWeight: FontWeight.bold),
                            ),
                          ),
                          if (sessions.length > 1) ...[
                            const SizedBox(width: 8),
                            GestureDetector(
                              onTap: _showSessionPicker,
                              child: const Row(
                                children: [
                                  Text(
                                    'Đổi suất diễn',
                                    style: TextStyle(color: Color(0xFF06B6D4), fontSize: 11, fontWeight: FontWeight.bold),
                                  ),
                                  Icon(Icons.keyboard_arrow_down, color: Color(0xFF06B6D4), size: 16),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '${_formatSessionTime(_selectedSession!['start_time'], _selectedSession!['end_time'])} • ${_formatShortDate(_selectedSession!['start_time'])}',
                        style: const TextStyle(color: Colors.white70, fontSize: 11),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildSeatItem(SessionSeatItem seat) {
    final isSelected = _selectedSeatIds.contains(seat.sessionSeatId);
    final isAvail = seat.isAvailable;
    final zoneColor = _getSeatColor(seat);
    final labelText = seat.rowLabel.isNotEmpty
        ? '${seat.rowLabel}${seat.seatNumber}'
        : seat.label;

    return GestureDetector(
      onTap: () => _toggleSeat(seat),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFFE6C17A)
              : !isAvail
                  ? const Color(0xFF1E293B)
                  : const Color(0xFF101932),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: isSelected
                ? const Color(0xFFFFF0C2)
                : !isAvail
                    ? const Color(0xFF334155)
                    : zoneColor.withValues(alpha: 0.8),
            width: isSelected ? 1.5 : 1.0,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: const Color(0xFFE6C17A).withValues(alpha: 0.5),
                    blurRadius: 6,
                    offset: const Offset(0, 1),
                  ),
                ]
              : null,
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Center(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 1),
                  child: Text(
                    labelText,
                    style: TextStyle(
                      color: isSelected
                          ? const Color(0xFF070D1E)
                          : !isAvail
                              ? const Color(0xFF64748B)
                              : Colors.white,
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
            if (!isSelected && isAvail)
              Positioned(
                bottom: 2,
                child: Container(
                  width: 14,
                  height: 2.5,
                  decoration: BoxDecoration(
                    color: zoneColor,
                    borderRadius: BorderRadius.circular(1),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildLegendItem(Color color, String label, {bool isBorderOnly = false}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 14,
          height: 14,
          decoration: BoxDecoration(
            color: isBorderOnly ? Colors.transparent : color,
            borderRadius: BorderRadius.circular(3),
            border: Border.all(color: color, width: 1.5),
          ),
        ),
        const SizedBox(width: 5),
        Text(
          label,
          style: const TextStyle(color: Color(0xFF8B9CB5), fontSize: 11),
        ),
      ],
    );
  }

  Widget _buildZoomButton(IconData icon, VoidCallback onTap, String tooltip) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: const Color(0xFF0F1A36).withValues(alpha: 0.9),
            shape: BoxShape.circle,
            border: Border.all(color: const Color(0xFF06B6D4).withValues(alpha: 0.4)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.4),
                blurRadius: 6,
              ),
            ],
          ),
          alignment: Alignment.center,
          child: Icon(icon, color: const Color(0xFF06B6D4), size: 18),
        ),
      ),
    );
  }

  Widget _buildSeatMapSection(List<Map<String, dynamic>> ticketTypes) {
    final hasPositions = _sessionSeats.any((s) => s.xPosition != 0 || s.yPosition != 0);
    final positioned = hasPositions ? _sessionSeats : <SessionSeatItem>[];

    final config = _seatMapData?['config'] as Map<String, dynamic>? ?? {};
    final stagePosition = config['stagePosition'] ?? _seatMapData?['stage_position'];
    final hasStage = stagePosition != null && stagePosition != 'HIDDEN';
    final stageLabel = config['stageLabel']?.toString() ?? 'SÂN KHẤU CHÍNH';

    const double seatWidth = 32.0;
    const double seatHeight = 32.0;
    const double padding = 20.0;

    double minX = 0;
    double maxX = 360;
    double minY = 0;
    double maxY = 260;

    double stageX = 0;
    double stageY = 0;
    double stageW = 320;
    double stageH = 44;

    if (positioned.isNotEmpty) {
      final List<double> allX = positioned.map((s) => s.xPosition).toList()
        ..addAll(positioned.map((s) => s.xPosition + seatWidth));
      final List<double> allY = positioned.map((s) => s.yPosition).toList()
        ..addAll(positioned.map((s) => s.yPosition + seatHeight));

      final seatsMinX = positioned.map((s) => s.xPosition).reduce(min);
      final seatsMaxX = positioned.map((s) => s.xPosition + seatWidth).reduce(max);
      final seatsMinY = positioned.map((s) => s.yPosition).reduce(min);

      final rawStageX = config['stageX'] ?? _seatMapData?['custom_stage_x'];
      stageX = (rawStageX as num?)?.toDouble() ?? seatsMinX;
      final rawStageY = config['stageY'] ?? _seatMapData?['custom_stage_y'];
      stageY = (rawStageY as num?)?.toDouble() ?? max(0.0, seatsMinY - 56.0);
      final rawStageW = config['stageWidth'] ?? _seatMapData?['custom_stage_width'];
      stageW = (rawStageW as num?)?.toDouble() ?? max(280.0, seatsMaxX - seatsMinX);
      final rawStageH = config['stageHeight'] ?? _seatMapData?['custom_stage_height'];
      stageH = (rawStageH as num?)?.toDouble() ?? 44.0;

      if (hasStage) {
        allX.add(stageX);
        allX.add(stageX + stageW);
        allY.add(stageY);
        allY.add(stageY + stageH);
      }

      minX = allX.reduce(min);
      maxX = allX.reduce(max);
      minY = allY.reduce(min);
      maxY = allY.reduce(max);
    }

    final canvasW = max(340.0, maxX - minX + padding * 2);
    final canvasH = max(260.0, maxY - minY + padding * 2);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF0C1446),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.secondary.withValues(alpha: 0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.event_seat_rounded, color: AppColors.primaryContainer, size: 18),
              SizedBox(width: 8),
              Text(
                'Sơ đồ ghế ngồi trực quan',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            'Chạm vào từng ghế để chọn chỗ cho khách mua tại quầy. Dùng 2 ngón tay hoặc nút bên phải để phóng to / thu nhỏ.',
            style: TextStyle(color: AppColors.secondary, fontSize: 12),
          ),
          const SizedBox(height: 12),

          // Legends
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildLegendItem(const Color(0xFFE6C17A), 'Đang chọn'),
              const SizedBox(width: 14),
              _buildLegendItem(const Color(0xFF06B6D4), 'Còn trống', isBorderOnly: true),
              const SizedBox(width: 14),
              _buildLegendItem(const Color(0xFF334155), 'Đã bán/giữ'),
            ],
          ),
          const SizedBox(height: 10),

          // Ticket type pills
          if (ticketTypes.isNotEmpty) ...[
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: ticketTypes.map((t) {
                  final tId = t['id']?.toString() ?? '';
                  final tName = t['name']?.toString() ?? '';
                  final price = double.tryParse(t['price']?.toString() ?? '0') ?? 0;
                  final matchingSeat = _sessionSeats.firstWhere(
                    (s) =>
                        s.ticketTypeIds.contains(tId) ||
                        (s.zoneName != null &&
                            s.zoneName!.trim().toLowerCase() == tName.trim().toLowerCase()),
                    orElse: () => _sessionSeats.first,
                  );
                  final c = _getSeatColor(matchingSeat);
                  return Container(
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF101932),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: c.withValues(alpha: 0.5)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(color: c, shape: BoxShape.circle),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '$tName (${_currencyFormat.format(price)})',
                          style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 12),
          ],

          // Canvas Viewport with Auto-Fit
          LayoutBuilder(
            builder: (context, constraints) {
              final viewportW = constraints.maxWidth;
              const viewportH = 340.0;

              final scaleX = (viewportW - 16) / canvasW;
              final scaleY = (viewportH - 16) / canvasH;
              final fitScale = min(scaleX, scaleY).clamp(0.05, 1.0);

              final renderedW = canvasW * fitScale;
              final renderedH = canvasH * fitScale;
              final dx = max(0.0, (viewportW - renderedW) / 2);
              final dy = max(0.0, (viewportH - renderedH) / 2);

              // ignore: deprecated_member_use
              final fitMatrix = Matrix4.identity()
                // ignore: deprecated_member_use
                ..translate(dx, dy)
                // ignore: deprecated_member_use
                ..scale(fitScale, fitScale, 1.0);

              _lastFitMatrix = fitMatrix;
              _fitScale = fitScale;
              _lastViewportSize = Size(viewportW, viewportH);

              if (!_hasFittedSeatMap) {
                _hasFittedSeatMap = true;
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted) {
                    _seatMapController.value = fitMatrix;
                  }
                });
              }

              return Container(
                height: viewportH,
                decoration: BoxDecoration(
                  color: const Color(0xFF080E22),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                ),
                clipBehavior: Clip.antiAlias,
                child: Stack(
                  children: [
                    InteractiveViewer(
                      transformationController: _seatMapController,
                      constrained: false,
                      boundaryMargin: EdgeInsets.all(viewportW * 0.5),
                      minScale: min(0.05, fitScale * 0.8),
                      maxScale: 4.5,
                      child: SizedBox(
                        width: canvasW,
                        height: canvasH,
                        child: Stack(
                          clipBehavior: Clip.none,
                          children: [
                            // Stage
                            if (hasStage)
                              Positioned(
                                left: stageX - minX + padding,
                                top: stageY - minY + padding,
                                width: stageW,
                                height: stageH,
                                child: Container(
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF1E3A8A).withValues(alpha: 0.85),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: const Color(0xFF3B82F6), width: 1.5),
                                    boxShadow: [
                                      BoxShadow(
                                        color: const Color(0xFF3B82F6).withValues(alpha: 0.3),
                                        blurRadius: 10,
                                      ),
                                    ],
                                  ),
                                  child: Text(
                                    stageLabel,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w900,
                                      fontSize: 12,
                                      letterSpacing: 2,
                                    ),
                                  ),
                                ),
                              ),

                            // Seats
                            if (positioned.isNotEmpty)
                              ...positioned.map((seat) {
                                final left = seat.xPosition - minX + padding;
                                final top = seat.yPosition - minY + padding;
                                return Positioned(
                                  left: left,
                                  top: top,
                                  width: seatWidth,
                                  height: seatHeight,
                                  child: _buildSeatItem(seat),
                                );
                              })
                            else
                              Center(
                                child: SingleChildScrollView(
                                  padding: const EdgeInsets.all(padding),
                                  child: Wrap(
                                    spacing: 6,
                                    runSpacing: 6,
                                    alignment: WrapAlignment.center,
                                    children: _sessionSeats.map((seat) {
                                      return SizedBox(
                                        width: seatWidth,
                                        height: seatHeight,
                                        child: _buildSeatItem(seat),
                                      );
                                    }).toList(),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),

                    // Floating Zoom controls
                    Positioned(
                      right: 12,
                      bottom: 12,
                      child: Column(
                        children: [
                          _buildZoomButton(Icons.add, _zoomIn, 'Phóng to'),
                          const SizedBox(height: 6),
                          _buildZoomButton(Icons.restart_alt_rounded, _resetZoom, 'Căn giữa'),
                          const SizedBox(height: 6),
                          _buildZoomButton(Icons.remove, _zoomOut, 'Thu nhỏ'),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),

          // Selected Seats Chips List
          if (_selectedSeats.isNotEmpty) ...[
            const SizedBox(height: 14),
            const Text(
              'Ghế đã chọn:',
              style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _selectedSeats.map((seat) {
                final tt = _getTicketTypeForSeat(seat);
                final price = double.tryParse(tt?['price']?.toString() ?? '0') ?? 0;
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF141F3C),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFFE6C17A)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${seat.label} (${tt?['name'] ?? 'Vé'} - ${_currencyFormat.format(price)})',
                        style: const TextStyle(
                          color: Color(0xFFE6C17A),
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: 6),
                      GestureDetector(
                        onTap: () => _toggleSeat(seat),
                        child: const Icon(Icons.close_rounded, color: Colors.white70, size: 14),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ],

          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Đã chọn: ${_selectedSeatIds.length} / 10 ghế',
                style: const TextStyle(color: Color(0xFF06B6D4), fontSize: 12, fontWeight: FontWeight.bold),
              ),
              const Text(
                '(Tối đa 10 vé mỗi đơn)',
                style: TextStyle(color: AppColors.secondary, fontSize: 11),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEventLayoutMap(List<Map<String, dynamic>> ticketTypes) {
    final bgImageUrl = _seatMapData?['background_image_url'] ??
        _seatMapData?['seat_map']?['background_image_url'] ??
        _selectedEvent?['layout_image_url'] ??
        _selectedEvent?['layout_map_url'];

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF0C1446),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF06B6D4).withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: const Color(0xFF06B6D4).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.map_outlined, color: Color(0xFF06B6D4), size: 18),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'SƠ ĐỒ MẶT BẰNG SỰ KIỆN',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Sự kiện vé tự do (không đánh số ghế). Sơ đồ vị trí sân khấu & phân khu khán giả.',
                      style: TextStyle(color: AppColors.secondary, fontSize: 11),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // If there is a layout map background image, show it
          if (bgImageUrl != null && bgImageUrl.toString().isNotEmpty) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.network(
                bgImageUrl.toString(),
                width: double.infinity,
                height: 180,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const SizedBox.shrink(),
              ),
            ),
            const SizedBox(height: 12),
          ],

          // Schematic Arena Layout Map
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF080E22),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
            ),
            child: Column(
              children: [
                // 1. Stage Box
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF1E3A8A), Color(0xFF2563EB), Color(0xFF1E3A8A)],
                    ),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFF60A5FA), width: 1.5),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF3B82F6).withValues(alpha: 0.4),
                        blurRadius: 12,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: const Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.mic, color: Colors.white, size: 14),
                          SizedBox(width: 8),
                          Text(
                            'SÂN KHẤU CHÍNH / MAIN STAGE',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                              fontSize: 12,
                              letterSpacing: 1.5,
                            ),
                          ),
                          SizedBox(width: 8),
                          Icon(Icons.speaker, color: Colors.white, size: 14),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 8),
                // Light beam visual
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    Icon(Icons.arrow_downward, color: const Color(0xFF60A5FA).withValues(alpha: 0.4), size: 14),
                    Icon(Icons.arrow_downward, color: const Color(0xFF60A5FA).withValues(alpha: 0.4), size: 14),
                    Icon(Icons.arrow_downward, color: const Color(0xFF60A5FA).withValues(alpha: 0.4), size: 14),
                  ],
                ),
                const SizedBox(height: 8),

                // 2. Audience / Standing Zones
                if (ticketTypes.isNotEmpty) ...[
                  ...ticketTypes.map((t) {
                    final tId = t['id']?.toString() ?? '';
                    final tName = t['name']?.toString() ?? 'Khu vực tự do';
                    final price = double.tryParse(t['price']?.toString() ?? '0') ?? 0;
                    final qty = _selectedQuantities[tId] ?? 0;
                    final isSelected = qty > 0;
                    final remaining = t['remaining_quantity'] ?? t['available_quantity'] ?? 99;

                    final palette = [
                      const Color(0xFFF59E0B),
                      const Color(0xFF3B82F6),
                      const Color(0xFF10B981),
                      const Color(0xFFA855F7),
                      const Color(0xFFEC4899),
                    ];
                    final idx = ticketTypes.indexOf(t);
                    final zoneColor = palette[idx % palette.length];

                    return Container(
                      width: double.infinity,
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? zoneColor.withValues(alpha: 0.18)
                            : const Color(0xFF101932),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isSelected ? zoneColor : zoneColor.withValues(alpha: 0.4),
                          width: isSelected ? 1.5 : 1.0,
                        ),
                        boxShadow: isSelected
                            ? [
                                BoxShadow(
                                  color: zoneColor.withValues(alpha: 0.25),
                                  blurRadius: 8,
                                ),
                              ]
                            : null,
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(
                              color: zoneColor,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'KHU VỰC: $tName',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Giá vé: ${_currencyFormat.format(price)} • Còn $remaining vé',
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.7),
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (isSelected)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: zoneColor.withValues(alpha: 0.3),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                'Đang chọn $qty vé',
                                style: TextStyle(
                                  color: zoneColor,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 11,
                                ),
                              ),
                            ),
                        ],
                      ),
                    );
                  }),
                ] else ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    decoration: BoxDecoration(
                      color: const Color(0xFF101932),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFF3B82F6).withValues(alpha: 0.3)),
                    ),
                    child: const Center(
                      child: Text(
                        'KHU VỰC ĐỨNG TỰ DO (GENERAL ADMISSION)',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
                ],

                const SizedBox(height: 12),

                // 3. Technical booth & Gates
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF101932),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: Colors.white12),
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.tune, color: Color(0xFF94A3B8), size: 12),
                            SizedBox(width: 4),
                            Text(
                              'KHU KỸ THUẬT FOH',
                              style: TextStyle(color: Color(0xFF94A3B8), fontSize: 10, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF22C55E).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: const Color(0xFF22C55E).withValues(alpha: 0.3)),
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.door_front_door_outlined, color: Color(0xFF22C55E), size: 12),
                            SizedBox(width: 4),
                            Text(
                              'CỔNG VÀO / SOÁT VÉ',
                              style: TextStyle(color: Color(0xFF22C55E), fontSize: 10, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTicketTypesList() {
    final ticketTypes = _getCurrentTicketTypes();

    if (_isLoadingSeats) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 36),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: const Color(0xFF0C1446),
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Column(
          children: [
            CircularProgressIndicator(color: AppColors.primaryContainer),
            SizedBox(height: 12),
            Text(
              'Đang tải sơ đồ vị trí & danh sách vé...',
              style: TextStyle(color: AppColors.secondary, fontSize: 13),
            ),
          ],
        ),
      );
    }

    if (ticketTypes.isEmpty && _sessionSeats.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF0C1446),
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Center(
          child: Text(
            'Không có loại vé nào đang mở bán cho sự kiện này.',
            style: TextStyle(color: AppColors.secondary, fontSize: 13),
          ),
        ),
      );
    }

    if (_hasSeatMap && _sessionSeats.isNotEmpty) {
      // 1. Seated Event Flow: Interactive Seat Map + Ticket types summary
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSeatMapSection(ticketTypes),
          const SizedBox(height: 14),
          const Text(
            'Danh mục hạng vé ghế ngồi:',
            style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          ...ticketTypes.map((tt) {
            final id = tt['id']?.toString() ?? '';
            final name = tt['name']?.toString() ?? 'Loại vé';
            final price = double.tryParse(tt['price']?.toString() ?? '0') ?? 0;
            final remaining = tt['remaining_quantity'] ?? tt['available_quantity'] ?? 99;
            final isSeated = tt['is_seated'] == true || tt['is_seated'] == 1 || tt['is_seated'] == 'true';

            final selectedCountForType = _selectedSeats.where((s) {
              final seatTt = _getTicketTypeForSeat(s);
              return seatTt?['id']?.toString() == id;
            }).length;

            final currentQty = _selectedQuantities[id] ?? 0;

            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: selectedCountForType > 0 || currentQty > 0
                    ? const Color(0xFF141F3C)
                    : const Color(0xFF0C1446),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: selectedCountForType > 0 || currentQty > 0
                      ? AppColors.primaryContainer.withValues(alpha: 0.6)
                      : AppColors.secondary.withValues(alpha: 0.15),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(name, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Text(
                              _currencyFormat.format(price),
                              style: const TextStyle(color: AppColors.primaryContainer, fontSize: 12, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '• Còn $remaining vé',
                              style: const TextStyle(color: AppColors.secondary, fontSize: 11),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  if (isSeated)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: selectedCountForType > 0
                            ? const Color(0xFFE6C17A).withValues(alpha: 0.2)
                            : const Color(0xFF122155),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: selectedCountForType > 0
                              ? const Color(0xFFE6C17A)
                              : Colors.white12,
                        ),
                      ),
                      child: Text(
                        selectedCountForType > 0
                            ? 'Đã chọn $selectedCountForType ghế'
                            : 'Chọn trên sơ đồ',
                        style: TextStyle(
                          color: selectedCountForType > 0
                              ? const Color(0xFFE6C17A)
                              : AppColors.secondary,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    )
                  else
                    // Unseated ticket type in a mixed event: stepper
                    Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFF122155),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.remove, color: Colors.white70, size: 16),
                            padding: const EdgeInsets.all(4),
                            constraints: const BoxConstraints(),
                            onPressed: currentQty > 0
                                ? () {
                                    setState(() {
                                      _selectedQuantities[id] = currentQty - 1;
                                    });
                                  }
                                : null,
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            child: Text(
                              '$currentQty',
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.add, color: AppColors.primaryContainer, size: 16),
                            padding: const EdgeInsets.all(4),
                            constraints: const BoxConstraints(),
                            onPressed: () {
                              setState(() {
                                _selectedQuantities[id] = currentQty + 1;
                              });
                            },
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            );
          }),
        ],
      );
    }

    // 2. Unseated Event Flow: Event Layout Map + Quantity Steppers
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // SƠ ĐỒ SỰ KIỆN
        _buildEventLayoutMap(ticketTypes),

        const SizedBox(height: 8),
        const Text(
          'Chọn số lượng vé:',
          style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),

        ...ticketTypes.map((tt) {
          final id = tt['id']?.toString() ?? '';
          final name = tt['name']?.toString() ?? 'Loại vé';
          final price = double.tryParse(tt['price']?.toString() ?? '0') ?? 0;
          final remaining = tt['remaining_quantity'] ?? tt['available_quantity'] ?? 99;
          final currentQty = _selectedQuantities[id] ?? 0;

          return Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFF0C1446),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: currentQty > 0 ? AppColors.primaryContainer.withValues(alpha: 0.5) : AppColors.secondary.withValues(alpha: 0.15),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Text(
                            _currencyFormat.format(price),
                            style: const TextStyle(color: AppColors.primaryContainer, fontSize: 13, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '• Còn $remaining vé',
                            style: const TextStyle(color: AppColors.secondary, fontSize: 11),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                // Counter Stepper (- / qty / +)
                Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF122155),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.remove, color: Colors.white70, size: 18),
                        padding: const EdgeInsets.all(6),
                        constraints: const BoxConstraints(),
                        onPressed: currentQty > 0
                            ? () {
                                setState(() {
                                  _selectedQuantities[id] = currentQty - 1;
                                });
                              }
                            : null,
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        child: Text(
                          '$currentQty',
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.add, color: AppColors.primaryContainer, size: 18),
                        padding: const EdgeInsets.all(6),
                        constraints: const BoxConstraints(),
                        onPressed: () {
                          setState(() {
                            _selectedQuantities[id] = currentQty + 1;
                          });
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _buildCustomerForm() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF0C1446),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.secondary.withValues(alpha: 0.15)),
      ),
      child: Column(
        children: [
          _buildTextField(
            controller: _buyerNameController,
            label: 'Họ và tên người mua (*)',
            hint: 'Nguyễn Văn A',
            icon: Icons.person,
            validator: (val) => val == null || val.trim().isEmpty ? 'Vui lòng nhập tên người mua' : null,
          ),
          const SizedBox(height: 12),
          _buildTextField(
            controller: _buyerPhoneController,
            label: 'Số điện thoại liên hệ (*)',
            hint: '0901234567',
            icon: Icons.phone,
            keyboardType: TextInputType.phone,
            validator: (val) {
              if (val == null || val.trim().isEmpty) return 'Vui lòng nhập số điện thoại';
              final clean = val.trim();
              if (clean.length < 9 || clean.length > 12) return 'Số điện thoại không hợp lệ';
              return null;
            },
          ),
          const SizedBox(height: 12),
          _buildTextField(
            controller: _buyerEmailController,
            label: 'Email nhận vé điện tử (Tùy chọn)',
            hint: 'khachhang@gmail.com',
            icon: Icons.email,
            keyboardType: TextInputType.emailAddress,
          ),
          const SizedBox(height: 12),
          _buildTextField(
            controller: _internalNoteController,
            label: 'Ghi chú nội bộ quầy bán',
            hint: 'Ví dụ: Đã thu tiền mặt, khách đoàn, ...',
            icon: Icons.notes,
          ),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: AppColors.secondary, fontSize: 12, fontWeight: FontWeight.bold)),
        const SizedBox(height: 6),
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFF122155),
            borderRadius: BorderRadius.circular(12),
          ),
          child: TextFormField(
            controller: controller,
            keyboardType: keyboardType,
            style: const TextStyle(color: Colors.white, fontSize: 14),
            validator: validator,
            decoration: InputDecoration(
              prefixIcon: Icon(icon, color: AppColors.secondary, size: 18),
              hintText: hint,
              hintStyle: const TextStyle(color: Colors.white24, fontSize: 13),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPaymentMethodSelector() {
    return Row(
      children: [
        Expanded(
          child: _buildPaymentMethodTile(
            method: 'cash',
            title: 'Tiền mặt',
            subtitle: 'Thu tiền trực tiếp',
            icon: Icons.money,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildPaymentMethodTile(
            method: 'bank_transfer',
            title: 'Chuyển khoản',
            subtitle: 'Quét QR ngân hàng',
            icon: Icons.qr_code_2,
          ),
        ),
      ],
    );
  }

  Widget _buildPaymentMethodTile({
    required String method,
    required String title,
    required String subtitle,
    required IconData icon,
  }) {
    final isSelected = _paymentMethod == method;
    return GestureDetector(
      onTap: () => setState(() => _paymentMethod = method),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFF0C1446),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? AppColors.primaryContainer : AppColors.secondary.withValues(alpha: 0.15),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Icon(icon, color: isSelected ? AppColors.primaryContainer : AppColors.secondary, size: 24),
                if (isSelected)
                  const Icon(Icons.check_circle, color: AppColors.primaryContainer, size: 18),
              ],
            ),
            const SizedBox(height: 10),
            Text(title, style: TextStyle(color: isSelected ? Colors.white : Colors.white70, fontWeight: FontWeight.bold, fontSize: 13)),
            Text(subtitle, style: const TextStyle(color: AppColors.secondary, fontSize: 10)),
          ],
        ),
      ),
    );
  }

  Widget _buildCheckoutSummary() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF0C1446),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.secondary.withValues(alpha: 0.2)),
      ),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Flexible(
                flex: 2,
                child: Text('Tổng số lượng vé:', style: TextStyle(color: AppColors.secondary, fontSize: 13), softWrap: true),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 3,
                child: Text('$_totalTicketsCount vé', textAlign: TextAlign.end, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14), softWrap: true),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Flexible(
                flex: 2,
                child: Text('Phương thức thanh toán:', style: TextStyle(color: AppColors.secondary, fontSize: 13), softWrap: true),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 3,
                child: Text(
                  _paymentMethod == 'cash' ? 'Tiền mặt' : 'Chuyển khoản',
                  textAlign: TextAlign.end,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                  softWrap: true,
                ),
              ),
            ],
          ),
          const Divider(color: Colors.white12, height: 20),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              const Flexible(
                flex: 2,
                child: Text('TỔNG THANH TOÁN:', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14), softWrap: true),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 3,
                child: Text(
                  _currencyFormat.format(_totalPrice),
                  textAlign: TextAlign.end,
                  style: const TextStyle(
                    color: AppColors.primaryContainer,
                    fontWeight: FontWeight.bold,
                    fontSize: 20,
                    letterSpacing: 0.5,
                  ),
                  softWrap: true,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: _isSubmitting ? null : _handleDirectBooking,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryContainer,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                elevation: 4,
              ),
              child: _isSubmitting
                  ? const CircularProgressIndicator(color: Colors.white)
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          _paymentMethod == 'bank_transfer' ? Icons.qr_code_2 : Icons.point_of_sale,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            _paymentMethod == 'bank_transfer'
                                ? 'TẠO MÃ THANH TOÁN (PAYOS)'
                                : 'XÁC NHẬN BÁN VÉ TẠI QUẦY',
                            textAlign: TextAlign.center,
                            softWrap: true,
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, letterSpacing: 0.3),
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StaffPayosPaymentDialog extends StatefulWidget {
  final Map<String, dynamic> initialData;

  const _StaffPayosPaymentDialog({
    required this.initialData,
  });

  @override
  State<_StaffPayosPaymentDialog> createState() => _StaffPayosPaymentDialogState();
}

class _StaffPayosPaymentDialogState extends State<_StaffPayosPaymentDialog> {
  late Map<String, dynamic> _data;
  Timer? _pollingTimer;
  Timer? _countdownTimer;
  int _secondsLeft = 900;
  bool _isChecking = false;

  @override
  void initState() {
    super.initState();
    _data = widget.initialData;
    _parseExpiredTime();
    _startCountdown();
    _startPolling();
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    _countdownTimer?.cancel();
    super.dispose();
  }

  void _parseExpiredTime() {
    final order = _data['order'] is Map ? _data['order'] as Map : _data;
    final expiredAtStr = order['expired_at']?.toString();
    if (expiredAtStr != null && expiredAtStr.isNotEmpty) {
      try {
        final expiry = DateTime.parse(expiredAtStr).toUtc();
        final now = DateTime.now().toUtc();
        final diff = expiry.difference(now).inSeconds;
        _secondsLeft = diff > 0 ? diff : 0;
      } catch (_) {}
    }
  }

  void _startCountdown() {
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_secondsLeft > 0) {
        setState(() => _secondsLeft--);
      } else {
        timer.cancel();
        _pollingTimer?.cancel();
        if (mounted) setState(() {});
      }
    });
  }

  void _startPolling() {
    _pollingTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      _checkStatus(silent: true);
    });
  }

  Future<void> _checkStatus({bool silent = false}) async {
    final order = _data['order'] is Map ? _data['order'] as Map : _data;
    final orderId = order['id']?.toString() ?? _data['order_id']?.toString();
    if (orderId == null || orderId.isEmpty) return;

    if (!silent) setState(() => _isChecking = true);
    final statusData = await StaffService().getDirectBookingStatus(orderId);
    if (!silent && mounted) setState(() => _isChecking = false);

    if (statusData != null && mounted) {
      setState(() {
        _data = statusData;
        _parseExpiredTime();
      });
      final currentOrder = statusData['order'] is Map ? statusData['order'] as Map : statusData;
      final status = currentOrder['status']?.toString().toUpperCase();

      if (status == 'PAID') {
        _pollingTimer?.cancel();
        _countdownTimer?.cancel();
        Navigator.pop(context, _data);
      } else if (status == 'EXPIRED' || status == 'CANCELLED') {
        _pollingTimer?.cancel();
        _countdownTimer?.cancel();
      }
    }
  }

  String _formatTimer(int totalSeconds) {
    final m = totalSeconds ~/ 60;
    final s = totalSeconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  Future<void> _openPayosCheckout(String checkoutUrl) async {
    final uri = Uri.tryParse(checkoutUrl);
    if (uri != null) {
      try {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } catch (_) {}
    }
  }

  @override
  Widget build(BuildContext context) {
    final order = _data['order'] is Map ? _data['order'] as Map : _data;
    final payment = _data['payment'] is Map ? _data['payment'] as Map : {};

    final orderCode = order['order_code']?.toString() ?? _data['order_code']?.toString() ?? 'ORD-PAYOS';
    final buyerName = order['buyer_name']?.toString() ?? '';
    final buyerPhone = order['buyer_phone']?.toString() ?? '';
    final amount = order['total_amount'] ?? payment['amount'] ?? _data['total_amount'] ?? 0;
    final formattedAmount = NumberFormat.currency(locale: 'vi_VN', symbol: 'đ', decimalDigits: 0).format(amount);

    final qrCode = payment['qr_code']?.toString() ?? _data['qr_code']?.toString();
    final checkoutUrl = payment['checkout_url']?.toString() ?? _data['checkout_url']?.toString();

    final isExpired = _secondsLeft <= 0 || order['status']?.toString().toUpperCase() == 'EXPIRED';

    return Dialog(
      backgroundColor: const Color(0xFF0C1446),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: const BorderSide(color: Color(0xFF3B82F6), width: 1.5),
      ),
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.qr_code_2, color: Color(0xFF60A5FA), size: 24),
                      SizedBox(width: 8),
                      Text(
                        'THANH TOÁN PAYOS',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white70, size: 20),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),

              const SizedBox(height: 8),

              // Status badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                decoration: BoxDecoration(
                  color: isExpired
                      ? const Color(0xFFEF4444).withValues(alpha: 0.2)
                      : const Color(0xFFE6C17A).withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isExpired ? const Color(0xFFEF4444) : const Color(0xFFE6C17A),
                  ),
                ),
                child: Text(
                  isExpired ? 'ĐÃ HẾT HẠN' : 'Chờ thanh toán (PENDING)',
                  style: TextStyle(
                    color: isExpired ? const Color(0xFFEF4444) : const Color(0xFFE6C17A),
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),

              const SizedBox(height: 14),

              // Countdown timer (Thời gian giữ vé)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
                decoration: BoxDecoration(
                  color: const Color(0xFF101932),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isExpired
                        ? const Color(0xFFEF4444).withValues(alpha: 0.4)
                        : const Color(0xFFE6C17A).withValues(alpha: 0.4),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.timer_outlined,
                      color: isExpired ? const Color(0xFFEF4444) : const Color(0xFFE6C17A),
                      size: 18,
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        isExpired ? 'Hết thời gian giữ vé' : 'Thời gian giữ vé: ${_formatTimer(_secondsLeft)}',
                        softWrap: true,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: isExpired ? const Color(0xFFEF4444) : const Color(0xFFE6C17A),
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // VietQR Code Box
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: qrCode != null && qrCode.trim().isNotEmpty
                    ? Image.network(
                        PaymentPage.paymentQrImageSrc(qrCode),
                        width: 200,
                        height: 200,
                        fit: BoxFit.contain,
                        loadingBuilder: (_, child, prog) => prog == null
                            ? child
                            : const SizedBox(
                                width: 200,
                                height: 200,
                                child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                              ),
                        errorBuilder: (_, __, ___) => QrImageView(
                          data: qrCode,
                          version: QrVersions.auto,
                          size: 200,
                          backgroundColor: Colors.white,
                        ),
                      )
                    : const SizedBox(
                        width: 200,
                        height: 200,
                        child: Center(
                          child: Text(
                            'Đang tải mã QR PayOS...',
                            style: TextStyle(color: Colors.black54, fontSize: 13),
                          ),
                        ),
                      ),
              ),

              const SizedBox(height: 12),

              const Text(
                'Yêu cầu khách hàng quét mã VietQR bằng app Ngân hàng để thanh toán.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Color(0xFFB0CADD), fontSize: 12),
              ),

              const SizedBox(height: 14),

              // Booking summary details
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF101932),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    _buildRow('Mã đơn', orderCode, isMono: true),
                    const Divider(color: Colors.white12, height: 12),
                    _buildRow('Khách hàng', '$buyerName ($buyerPhone)'),
                    const Divider(color: Colors.white12, height: 12),
                    _buildRow('Số tiền', formattedAmount, isHighlight: true),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Actions
              if (checkoutUrl != null && checkoutUrl.isNotEmpty) ...[
                OutlinedButton.icon(
                  onPressed: () => _openPayosCheckout(checkoutUrl),
                  icon: const Icon(Icons.open_in_new, size: 16, color: Color(0xFF60A5FA)),
                  label: const Text(
                    'Mở Trang PayOS',
                    style: TextStyle(color: Color(0xFF60A5FA), fontSize: 13, fontWeight: FontWeight.bold),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFF3B82F6)),
                    minimumSize: const Size(double.infinity, 44),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 10),
              ],

              ElevatedButton.icon(
                onPressed: _isChecking ? null : () => _checkStatus(silent: false),
                icon: _isChecking
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.refresh, size: 18, color: Colors.white),
                label: Text(
                  _isChecking ? 'Đang kiểm tra...' : 'Kiểm tra trạng thái PayOS',
                  style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryContainer,
                  minimumSize: const Size(double.infinity, 46),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRow(String label, String value, {bool isHighlight = false, bool isMono = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Flexible(
            flex: 2,
            child: Text(
              label,
              style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
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
                color: isHighlight ? const Color(0xFF22C55E) : Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: isHighlight ? 14 : 12,
                fontFamily: isMono ? 'monospace' : null,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
