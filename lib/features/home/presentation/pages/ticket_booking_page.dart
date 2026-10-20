import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/api/auth_service.dart';
import '../../../../core/api/events_service.dart';
import '../../../../core/api/orders_service.dart';
import '../../../../core/models/event_model.dart';
import '../../../../core/models/user_model.dart';
import '../../../../core/theme/app_colors.dart';
import 'payment_page.dart';

class TicketBookingPage extends StatefulWidget {
  final EventModel event;
  final String? initialSessionId;
  final String? initialTicketTypeId;
  final int? initialQuantity;
  final String? initialBuyerName;
  final String? initialBuyerEmail;
  final String? initialBuyerPhone;

  const TicketBookingPage({
    super.key,
    required this.event,
    this.initialSessionId,
    this.initialTicketTypeId,
    this.initialQuantity,
    this.initialBuyerName,
    this.initialBuyerEmail,
    this.initialBuyerPhone,
  });

  @override
  State<TicketBookingPage> createState() => _TicketBookingPageState();
}

class SessionSeatItem {
  final String sessionSeatId;
  final String? seatId;
  final String rowLabel;
  final String seatNumber;
  final String label;
  final double xPosition;
  final double yPosition;
  final bool isDisabled;
  final String status; // AVAILABLE, HELD, SOLD, BLOCKED
  final List<String> ticketTypeIds;
  final String? zoneId;
  final String? zoneName;
  final Color? zoneColor;

  SessionSeatItem({
    required this.sessionSeatId,
    this.seatId,
    required this.rowLabel,
    required this.seatNumber,
    required this.label,
    required this.xPosition,
    required this.yPosition,
    required this.isDisabled,
    required this.status,
    required this.ticketTypeIds,
    this.zoneId,
    this.zoneName,
    this.zoneColor,
  });

  factory SessionSeatItem.fromJson(Map<String, dynamic> json) {
    Color? parsedColor;
    final zColorStr = json['zone']?['color'] ?? json['seat_type']?['color'];
    if (zColorStr != null && zColorStr.toString().startsWith('#')) {
      final hex = zColorStr.toString().replaceAll('#', '');
      final val = int.tryParse(hex, radix: 16);
      if (val != null) {
        parsedColor = Color(hex.length == 6 ? (0xFF000000 | val) : val);
      }
    }

    final rawRow = json['row_label']?.toString() ?? '';
    final rawNum = json['seat_number']?.toString() ?? '';
    final rawLabel = json['label']?.toString() ?? '$rawRow$rawNum';

    return SessionSeatItem(
      sessionSeatId: json['session_seat_id']?.toString() ?? json['id']?.toString() ?? '',
      seatId: json['seat_id']?.toString(),
      rowLabel: rawRow,
      seatNumber: rawNum,
      label: rawLabel,
      xPosition: (json['x_position'] as num?)?.toDouble() ?? 0.0,
      yPosition: (json['y_position'] as num?)?.toDouble() ?? 0.0,
      isDisabled: json['is_disabled'] == true,
      status: json['status']?.toString().toUpperCase() ?? 'AVAILABLE',
      ticketTypeIds: (json['ticket_type_ids'] as List?)?.map((e) => e.toString()).toList() ?? [],
      zoneId: json['zone']?['id']?.toString(),
      zoneName: json['zone']?['name']?.toString() ?? json['seat_type']?['name']?.toString(),
      zoneColor: parsedColor,
    );
  }

  bool get isAvailable => !isDisabled && status == 'AVAILABLE';
}

class _AttendeeSlotData {
  final String ticketTypeId;
  final String ticketName;
  final String? seatLabel;
  final String? sessionSeatId;
  final TextEditingController nameController;
  final TextEditingController emailController;

  _AttendeeSlotData({
    required this.ticketTypeId,
    required this.ticketName,
    this.seatLabel,
    this.sessionSeatId,
    String? initialName,
    String? initialEmail,
  })  : nameController = TextEditingController(text: initialName ?? ''),
        emailController = TextEditingController(text: initialEmail ?? '');

  void dispose() {
    nameController.dispose();
    emailController.dispose();
  }
}

class _TicketBookingPageState extends State<TicketBookingPage> {
  // Step state: 1 = Chọn vé, 2 = Thông tin, 3 = Kiểm tra
  int _currentStep = 1;

  late EventSessionModel? _selectedSession;
  final Map<String, int> _ticketQuantities = {};

  // Seat map state (when event/session has seats)
  bool _isLoadingSeats = false;
  bool _hasSeatMap = false;
  Map<String, dynamic>? _seatMapData;
  List<SessionSeatItem> _sessionSeats = [];
  final Set<String> _selectedSeatIds = {};
  final List<SessionSeatItem> _selectedSeats = [];
  final TransformationController _seatMapController = TransformationController();

  // Seat map viewport fitting state
  bool _hasFittedSeatMap = false;
  double _fitScale = 1.0;
  Matrix4? _lastFitMatrix;
  Size? _lastViewportSize;

  // Step 2: Buyer controllers
  final _buyerNameController = TextEditingController();
  final _buyerEmailController = TextEditingController();
  final _buyerPhoneController = TextEditingController();

  // Step 2: Attendee slots
  final List<_AttendeeSlotData> _attendeeSlots = [];

  // 15-minute Countdown Timer (matching Image 3 & Web)
  Timer? _countdownTimer;
  int _countdownSeconds = 900;

  // Bottom sheet summary status
  bool _isSummarySheetOpen = false;

  // Step 3: Promo & checkout
  final _promoController = TextEditingController();
  List<Map<String, dynamic>> _availablePromos = [];
  Map<String, dynamic>? _appliedPromo;
  String? _appliedPromoCode;
  double _promoDiscountAmount = 0.0;
  bool _termsAccepted = true;
  bool _isCheckingOut = false;

  @override
  void initState() {
    super.initState();

    // 1. Resolve selected session
    if (widget.initialSessionId != null &&
        widget.event.sessions.any((s) => s.id == widget.initialSessionId)) {
      _selectedSession = widget.event.sessions
          .firstWhere((s) => s.id == widget.initialSessionId);
    } else if (widget.event.sessions.isNotEmpty) {
      _selectedSession = widget.event.sessions.first;
    } else {
      _selectedSession = null;
    }

    // 2. Initialize ticket quantities
    _initTicketQuantities();

    // 3. Pre-populate buyer info from auth or props
    final user = AuthService().currentUser;
    if (user != null) {
      _buyerNameController.text = user.fullName;
      _buyerEmailController.text = user.email;
      _buyerPhoneController.text = user.phone ?? '';
    }
    if (widget.initialBuyerName != null && widget.initialBuyerName!.isNotEmpty) {
      _buyerNameController.text = widget.initialBuyerName!;
    }
    if (widget.initialBuyerEmail != null && widget.initialBuyerEmail!.isNotEmpty) {
      _buyerEmailController.text = widget.initialBuyerEmail!;
    }
    if (widget.initialBuyerPhone != null && widget.initialBuyerPhone!.isNotEmpty) {
      _buyerPhoneController.text = widget.initialBuyerPhone!;
    }

    // 4. Fetch user profile from API to ensure auto-fill
    _fetchUserProfile();

    // 5. Fetch available promos in background for Step 3
    _fetchPromos();

    // 6. Load session seats if session selected
    if (_selectedSession != null) {
      _loadSessionSeats(_selectedSession!.id);
    }
  }

  Future<void> _fetchUserProfile() async {
    final cached = AuthService().currentUser;
    if (cached != null) {
      if (_buyerNameController.text.trim().isEmpty) _buyerNameController.text = cached.fullName;
      if (_buyerEmailController.text.trim().isEmpty) _buyerEmailController.text = cached.email;
      if (_buyerPhoneController.text.trim().isEmpty && cached.phone != null) _buyerPhoneController.text = cached.phone!;
    }

    if (_buyerNameController.text.trim().isEmpty ||
        _buyerEmailController.text.trim().isEmpty ||
        _buyerPhoneController.text.trim().isEmpty) {
      try {
        final res = await AuthService().fetchProfile();
        if (res['success'] == true && res['user'] is UserModel) {
          final u = res['user'] as UserModel;
          if (mounted) {
            setState(() {
              if (_buyerNameController.text.trim().isEmpty) _buyerNameController.text = u.fullName;
              if (_buyerEmailController.text.trim().isEmpty) _buyerEmailController.text = u.email;
              if (_buyerPhoneController.text.trim().isEmpty && u.phone != null) _buyerPhoneController.text = u.phone!;

              // Auto-fill attendees as well (only the first attendee gets buyer's info)
              if (_attendeeSlots.isNotEmpty) {
                final firstSlot = _attendeeSlots.first;
                if (firstSlot.nameController.text.trim().isEmpty) {
                  firstSlot.nameController.text = _buyerNameController.text.trim();
                }
                if (firstSlot.emailController.text.trim().isEmpty) {
                  firstSlot.emailController.text = _buyerEmailController.text.trim();
                }
              }
            });
          }
        }
      } catch (_) {}
    }
  }

  void _startCountdown() {
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_countdownSeconds > 0) {
        setState(() => _countdownSeconds--);
      } else {
        timer.cancel();
        _handleCountdownExpired();
      }
    });
  }

  void _handleCountdownExpired() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF101932),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 24),
            SizedBox(width: 8),
            Text('Hết thời gian giữ vé', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        content: const Text(
          'Thời gian giữ vé (15 phút) đã hết. Vui lòng chọn lại vé để tiếp tục đặt vé.',
          style: TextStyle(color: Color(0xFFB0CADD), fontSize: 13),
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              setState(() {
                _currentStep = 1;
                _countdownSeconds = 900;
              });
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFE6C17A),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Chọn lại vé', style: TextStyle(color: Color(0xFF070D1E), fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _initTicketQuantities() {
    final availableTypes = _getAvailableTicketTypes();
    for (final t in availableTypes) {
      _ticketQuantities[t.id] = 0;
    }

    if (_hasSeatMap) return;

    // Select initial ticket if provided or default first ticket to 1
    if (widget.initialTicketTypeId != null &&
        _ticketQuantities.containsKey(widget.initialTicketTypeId)) {
      _ticketQuantities[widget.initialTicketTypeId!] =
          widget.initialQuantity != null && widget.initialQuantity! > 0
              ? widget.initialQuantity!
              : 1;
    } else if (availableTypes.isNotEmpty) {
      final firstAvailable =
          availableTypes.firstWhere((t) => !t.isSoldOut, orElse: () => availableTypes.first);
      if (!firstAvailable.isSoldOut) {
        _ticketQuantities[firstAvailable.id] = 1;
      }
    }
  }

  Future<void> _loadSessionSeats(String sessionId) async {
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
        if (_hasSeatMap) {
          _ticketQuantities.clear();
        } else {
          _initTicketQuantities();
        }
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _isLoadingSeats = false;
          _hasSeatMap = false;
          _hasFittedSeatMap = false;
          _lastFitMatrix = null;
          _initTicketQuantities();
        });
      }
    }
  }

  TicketTypeModel? _getTicketTypeForSeat(SessionSeatItem seat) {
    final availableTypes = _getAvailableTicketTypes();
    if (seat.ticketTypeIds.isNotEmpty) {
      for (final tid in seat.ticketTypeIds) {
        for (final t in availableTypes) {
          if (t.id == tid) return t;
        }
      }
    }
    if (seat.zoneName != null && seat.zoneName!.isNotEmpty) {
      final zNameLower = seat.zoneName!.trim().toLowerCase();
      for (final t in availableTypes) {
        if (t.name.trim().toLowerCase() == zNameLower) return t;
      }
    }
    return availableTypes.isNotEmpty ? availableTypes.first : null;
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
      final types = _getAvailableTicketTypes();
      final idx = types.indexOf(tt);
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
        ),
      );
      return;
    }

    final ticketType = _getTicketTypeForSeat(seat);
    if (ticketType == null) return;

    setState(() {
      if (_selectedSeatIds.contains(seat.sessionSeatId)) {
        _selectedSeatIds.remove(seat.sessionSeatId);
        _selectedSeats.removeWhere((s) => s.sessionSeatId == seat.sessionSeatId);
        final currentQty = _ticketQuantities[ticketType.id] ?? 0;
        if (currentQty > 0) {
          _ticketQuantities[ticketType.id] = currentQty - 1;
        }
      } else {
        if (_selectedSeatIds.length >= 10) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Bạn chỉ được chọn tối đa 10 ghế trong một lần đặt.'),
              backgroundColor: AppColors.error,
            ),
          );
          return;
        }
        _selectedSeatIds.add(seat.sessionSeatId);
        _selectedSeats.add(seat);
        _ticketQuantities[ticketType.id] = (_ticketQuantities[ticketType.id] ?? 0) + 1;
      }
    });
  }

  void _zoomIn() {
    _zoomBy(1.3);
  }

  void _zoomOut() {
    _zoomBy(0.77);
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

    final matrix = Matrix4.identity()
      ..translate(newTx, newTy)
      ..scale(targetScale, targetScale, 1.0);

    _seatMapController.value = matrix;
  }

  void _resetZoom() {
    if (_lastFitMatrix != null) {
      _seatMapController.value = _lastFitMatrix!.clone();
    } else {
      _seatMapController.value = Matrix4.identity();
    }
  }

  Future<void> _fetchPromos() async {
    final promos = await OrdersService().getAvailablePromotions(widget.event.id);
    if (mounted) {
      setState(() {
        _availablePromos = promos;
      });
    }
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _seatMapController.dispose();
    _buyerNameController.dispose();
    _buyerEmailController.dispose();
    _buyerPhoneController.dispose();
    _promoController.dispose();
    for (final slot in _attendeeSlots) {
      slot.dispose();
    }
    super.dispose();
  }

  List<TicketTypeModel> _getAvailableTicketTypes() {
    if (_selectedSession != null && _selectedSession!.ticketTypes.isNotEmpty) {
      return _selectedSession!.ticketTypes;
    }
    if (widget.event.ticketTypes.isNotEmpty) {
      return widget.event.ticketTypes;
    }
    return [
      TicketTypeModel(
        id: 'tt-standard',
        name: 'Vé Tiêu Chuẩn',
        price: widget.event.minPrice ?? 250000,
        availableQuantity: 100,
      ),
    ];
  }

  int get _totalSelectedQuantity {
    if (_hasSeatMap && _selectedSeatIds.isNotEmpty) {
      return _selectedSeatIds.length;
    }
    return _ticketQuantities.values.fold(0, (sum, q) => sum + q);
  }

  double get _subtotalPrice {
    if (_hasSeatMap && _selectedSeats.isNotEmpty) {
      double total = 0.0;
      for (final seat in _selectedSeats) {
        final tt = _getTicketTypeForSeat(seat);
        if (tt != null) {
          total += tt.price;
        }
      }
      return total;
    }
    final types = _getAvailableTicketTypes();
    double total = 0.0;
    for (final t in types) {
      final qty = _ticketQuantities[t.id] ?? 0;
      total += t.price * qty;
    }
    return total;
  }

  double get _finalPrice {
    return (_subtotalPrice - _promoDiscountAmount).clamp(0.0, double.infinity);
  }

  String _formatCurrency(double amount) {
    final formatter =
        NumberFormat.currency(locale: 'vi_VN', symbol: 'đ', decimalDigits: 0);
    return formatter.format(amount);
  }

  String _formatShortDate(String? dateStr) {
    if (dateStr == null) return 'Chưa cập nhật';
    try {
      final d = DateTime.parse(dateStr).toLocal();
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
      return dateStr;
    }
  }

  String _formatSessionTime(String? startStr, String? endStr) {
    if (startStr == null) return 'Chưa cập nhật';
    try {
      final start = DateTime.parse(startStr).toLocal();
      final startFormatted = DateFormat('HH:mm').format(start);
      if (endStr != null) {
        final end = DateTime.parse(endStr).toLocal();
        final endFormatted = DateFormat('HH:mm').format(end);
        return '$startFormatted - $endFormatted';
      }
      return startFormatted;
    } catch (_) {
      return startStr;
    }
  }

  // ==========================================
  // STEP NAVIGATION & VALIDATIONS
  // ==========================================
  void _syncAttendeeSlots() {
    final List<_AttendeeSlotData> newSlots = [];
    int existingIndex = 0;
    String defaultName = _buyerNameController.text.trim();
    String defaultEmail = _buyerEmailController.text.trim();

    final user = AuthService().currentUser;
    if (defaultName.isEmpty && user != null) {
      defaultName = user.fullName;
      if (_buyerNameController.text.trim().isEmpty) {
        _buyerNameController.text = defaultName;
      }
    }
    if (defaultEmail.isEmpty && user != null) {
      defaultEmail = user.email;
      if (_buyerEmailController.text.trim().isEmpty) {
        _buyerEmailController.text = defaultEmail;
      }
    }
    if (_buyerPhoneController.text.trim().isEmpty && user?.phone != null) {
      _buyerPhoneController.text = user!.phone!;
    }

    if (_hasSeatMap && _selectedSeats.isNotEmpty) {
      for (final seat in _selectedSeats) {
        final tt = _getTicketTypeForSeat(seat);
        // Only attendee 0 gets defaultName & defaultEmail; attendees 1+ are blank initially
        String initName = existingIndex == 0 ? defaultName : '';
        String initEmail = existingIndex == 0 ? defaultEmail : '';
        if (existingIndex < _attendeeSlots.length) {
          final oldName = _attendeeSlots[existingIndex].nameController.text.trim();
          final oldEmail = _attendeeSlots[existingIndex].emailController.text.trim();
          if (oldName.isNotEmpty) initName = oldName;
          if (oldEmail.isNotEmpty) initEmail = oldEmail;
        }

        newSlots.add(_AttendeeSlotData(
          ticketTypeId: tt?.id ?? 'tt-standard',
          ticketName: tt?.name ?? 'Vé tham dự',
          seatLabel: seat.label,
          sessionSeatId: seat.sessionSeatId,
          initialName: initName,
          initialEmail: initEmail,
        ));
        existingIndex++;
      }
    } else {
      final types = _getAvailableTicketTypes();
      for (final t in types) {
        final count = _ticketQuantities[t.id] ?? 0;
        for (int i = 0; i < count; i++) {
          // Only attendee 0 gets defaultName & defaultEmail; attendees 1+ are blank initially
          String initName = existingIndex == 0 ? defaultName : '';
          String initEmail = existingIndex == 0 ? defaultEmail : '';

          if (existingIndex < _attendeeSlots.length) {
            final oldName = _attendeeSlots[existingIndex].nameController.text.trim();
            final oldEmail = _attendeeSlots[existingIndex].emailController.text.trim();
            if (oldName.isNotEmpty) initName = oldName;
            if (oldEmail.isNotEmpty) initEmail = oldEmail;
          }

          newSlots.add(_AttendeeSlotData(
            ticketTypeId: t.id,
            ticketName: t.name,
            initialName: initName,
            initialEmail: initEmail,
          ));
          existingIndex++;
        }
      }
    }

    // Clean up old controllers
    for (final old in _attendeeSlots) {
      old.dispose();
    }
    _attendeeSlots.clear();
    _attendeeSlots.addAll(newSlots);
  }

  List<OrderItemInput> _buildOrderItems() {
    if (_hasSeatMap && _selectedSeats.isNotEmpty) {
      final Map<String, List<String>> seatsByType = {};
      for (final seat in _selectedSeats) {
        final tt = _getTicketTypeForSeat(seat);
        if (tt != null) {
          seatsByType.putIfAbsent(tt.id, () => []).add(seat.sessionSeatId);
        }
      }
      return seatsByType.entries.map((entry) {
        return OrderItemInput(
          ticketTypeId: entry.key,
          quantity: entry.value.length,
          sessionSeatIds: entry.value,
        );
      }).toList();
    }

    final types = _getAvailableTicketTypes();
    final List<OrderItemInput> items = [];
    for (final t in types) {
      final qty = _ticketQuantities[t.id] ?? 0;
      if (qty > 0) {
        items.add(OrderItemInput(ticketTypeId: t.id, quantity: qty));
      }
    }
    return items;
  }

  Future<void> _goToStep2() async {
    if (_totalSelectedQuantity <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_hasSeatMap ? 'Vui lòng chọn ít nhất 1 ghế để tiếp tục!' : 'Vui lòng chọn ít nhất 1 vé để tiếp tục!'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    // Optionally hold seats on backend
    if (_hasSeatMap && _selectedSeats.isNotEmpty) {
      try {
        final payload = {
          'event_id': widget.event.id,
          'items': _buildOrderItems().map((i) => i.toJson()).toList(),
        };
        await EventsService().holdSeats(payload);
      } catch (_) {}
    }

    // Ensure user profile is loaded before advancing
    if (_buyerNameController.text.trim().isEmpty ||
        _buyerEmailController.text.trim().isEmpty ||
        _buyerPhoneController.text.trim().isEmpty) {
      await _fetchUserProfile();
    }

    _syncAttendeeSlots();
    _startCountdown();
    setState(() => _currentStep = 2);
  }

  void _goToStep3() {
    final buyerName = _buyerNameController.text.trim();
    final buyerEmail = _buyerEmailController.text.trim();
    final buyerPhone = _buyerPhoneController.text.trim();

    if (buyerName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vui lòng nhập họ và tên người mua vé!'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    final emailRegex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
    if (!emailRegex.hasMatch(buyerEmail)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Email người nhận vé không hợp lệ!'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    if (buyerPhone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vui lòng nhập số điện thoại liên hệ!'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    // Validate attendees if required
    if (widget.event.requireAttendeeInfo == true) {
      for (int i = 0; i < _attendeeSlots.length; i++) {
        final slot = _attendeeSlots[i];
        final name = slot.nameController.text.trim();
        final email = slot.emailController.text.trim();
        if (name.isEmpty || email.isEmpty || !emailRegex.hasMatch(email)) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Vui lòng nhập đầy đủ tên và email hợp lệ cho vé ${i + 1} (${slot.ticketName})!'),
              backgroundColor: AppColors.error,
            ),
          );
          return;
        }
      }
    }

    _recalculatePromoDiscount();
    setState(() => _currentStep = 3);
  }

  void _applyPromoCode(String rawCode) {
    final code = rawCode.trim().toUpperCase();
    if (code.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng nhập mã voucher / khuyến mãi!'), backgroundColor: Colors.orange),
      );
      return;
    }

    final found = _availablePromos.firstWhere(
      (p) => p['code']?.toString().toUpperCase() == code,
      orElse: () => {},
    );

    final subtotal = _subtotalPrice;

    if (found.isNotEmpty) {
      final minOrder = double.tryParse(found['min_order_value']?.toString() ?? '0') ?? 0.0;
      if (subtotal < minOrder) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Đơn hàng cần tối thiểu ${_formatCurrency(minOrder)} để áp dụng mã này.'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      setState(() {
        _appliedPromo = found;
        _appliedPromoCode = found['code'];
        _promoController.text = found['code'];
      });
      _recalculatePromoDiscount();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Đã áp dụng mã giảm giá ${found['code']} thành công!'),
          backgroundColor: const Color(0xFF06B6D4),
        ),
      );
    } else {
      // Saved promo code for checkout
      setState(() {
        _appliedPromo = null;
        _appliedPromoCode = code;
        _promoController.text = code;
        _promoDiscountAmount = 0.0;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Đã lưu mã $code. Hệ thống sẽ áp dụng khi thanh toán.'),
          backgroundColor: const Color(0xFF06B6D4),
        ),
      );
    }
  }

  void _removePromoCode() {
    setState(() {
      _appliedPromo = null;
      _appliedPromoCode = null;
      _promoController.clear();
      _promoDiscountAmount = 0.0;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Đã hủy áp dụng mã khuyến mãi.')),
    );
  }

  void _recalculatePromoDiscount() {
    if (_appliedPromo == null) {
      _promoDiscountAmount = 0.0;
      return;
    }

    final discountType = _appliedPromo!['discount_type']?.toString().toUpperCase();
    final discountVal = double.tryParse(_appliedPromo!['discount_value']?.toString() ?? '0') ?? 0.0;
    final maxDiscount = _appliedPromo!['max_discount'] != null
        ? double.tryParse(_appliedPromo!['max_discount'].toString())
        : null;

    final subtotal = _subtotalPrice;
    double calculated = 0.0;

    if (discountType == 'PERCENTAGE') {
      calculated = (subtotal * discountVal) / 100;
      if (maxDiscount != null && maxDiscount > 0) {
        calculated = calculated.clamp(0.0, maxDiscount);
      }
    } else {
      calculated = discountVal;
    }

    _promoDiscountAmount = calculated.clamp(0.0, subtotal);
  }

  Future<void> _handleCheckout() async {
    if (!_termsAccepted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vui lòng đọc và tick chọn xác nhận đồng ý với điều khoản tham dự và chính sách hoàn tiền của sự kiện trước khi tiếp tục.'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    final buyerName = _buyerNameController.text.trim();
    final buyerEmail = _buyerEmailController.text.trim();
    final buyerPhone = _buyerPhoneController.text.trim();

    setState(() => _isCheckingOut = true);

    // Build items list
    final List<OrderItemInput> items = _buildOrderItems();

    // Build attendees list
    final List<OrderAttendeeInput> attendees = [];
    if (_attendeeSlots.isNotEmpty) {
      for (final slot in _attendeeSlots) {
        final name = slot.nameController.text.trim();
        final email = slot.emailController.text.trim();
        attendees.add(OrderAttendeeInput(
          ticketTypeId: slot.ticketTypeId,
          sessionSeatId: slot.sessionSeatId,
          name: name.isNotEmpty ? name : buyerName,
          email: email.isNotEmpty ? email : buyerEmail,
        ));
      }
    } else {
      for (final item in items) {
        if (item.sessionSeatIds.isNotEmpty) {
          for (final sId in item.sessionSeatIds) {
            attendees.add(OrderAttendeeInput(
              ticketTypeId: item.ticketTypeId,
              sessionSeatId: sId,
              name: buyerName,
              email: buyerEmail,
            ));
          }
        } else {
          for (int i = 0; i < item.quantity; i++) {
            attendees.add(OrderAttendeeInput(
              ticketTypeId: item.ticketTypeId,
              name: buyerName,
              email: buyerEmail,
            ));
          }
        }
      }
    }

    final result = await OrdersService().checkoutOrder(
      eventId: widget.event.id,
      buyerName: buyerName,
      buyerEmail: buyerEmail,
      buyerPhone: buyerPhone.isNotEmpty ? buyerPhone : null,
      promoCode: _appliedPromoCode,
      eventTermsAccepted: _termsAccepted,
      attendees: attendees,
      items: items,
    );

    setState(() => _isCheckingOut = false);

    if (mounted) {
      if (result['success'] == true && result['data'] != null) {
        final orderData = result['data'];
        final orderId = orderData['order']?['id']?.toString() ?? '';
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => PaymentPage(
              orderId: orderId,
              initialData: orderData,
            ),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message'] ?? 'Không thể tạo đơn hàng. Vui lòng thử lại.'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Widget _buildCountdownBanner() {
    final m = (_countdownSeconds ~/ 60).toString().padLeft(2, '0');
    final s = (_countdownSeconds % 60).toString().padLeft(2, '0');

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 16),
      color: const Color(0xFFDC2626), // red banner matching Image 3
      child: Center(
        child: RichText(
          text: TextSpan(
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
            children: [
              const TextSpan(text: 'Hoàn tất đặt vé trong   '),
              TextSpan(
                text: '$m : $s',
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 15,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderEventSummary() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF0C142A),
        border: Border(bottom: BorderSide(color: Colors.white.withOpacity(0.08))),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.event.title.toUpperCase(),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.2,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 6),
          if (_selectedSession != null) ...[
            Row(
              children: [
                const Icon(Icons.calendar_today_outlined, color: Color(0xFF8B9CB5), size: 13),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    '${_formatSessionTime(_selectedSession!.startTime, _selectedSession!.endTime)}, ${_formatShortDate(_selectedSession!.startTime)}',
                    style: const TextStyle(color: Color(0xFF8B9CB5), fontSize: 12),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            if (_selectedSession!.venue?.summary != null) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  const Icon(Icons.location_on_outlined, color: Color(0xFF8B9CB5), size: 13),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      _selectedSession!.venue!.summary!,
                      style: const TextStyle(color: Color(0xFF8B9CB5), fontSize: 12),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF070D1E),
      appBar: AppBar(
        backgroundColor: const Color(0xFF070D1E),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 18),
          onPressed: () {
            if (_currentStep == 3) {
              setState(() => _currentStep = 2);
            } else if (_currentStep == 2) {
              setState(() => _currentStep = 1);
            } else {
              Navigator.pop(context);
            }
          },
        ),
        title: Text(
          _currentStep == 1
              ? 'Chọn vé'
              : _currentStep == 2
                  ? 'Thông tin người nhận'
                  : 'Kiểm tra đơn hàng',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          // Red Countdown Banner for Step 2 and Step 3 (FIXED under AppBar)
          if (_currentStep >= 2) _buildCountdownBanner(),

          // Step Body (Scrollable - Header Event Summary scrolls with page so scrolling down hides it)
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_currentStep >= 2) _buildHeaderEventSummary(),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                    child: _currentStep == 1
                        ? _buildStep1SelectTickets()
                        : _currentStep == 2
                            ? _buildStep2BuyerInfo()
                            : _buildStep3ReviewOrder(),
                  ),
                ],
              ),
            ),
          ),

          // Bottom Fixed Action Bar
          _buildBottomBar(),
        ],
      ),
    );
  }

  // ==========================================
  // STEP 1: CHỌN VÉ
  // ==========================================
  Widget _buildStep1SelectTickets() {
    final ticketTypes = _getAvailableTicketTypes();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. Session Card
        if (_selectedSession != null) ...[
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFF101932),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFC99A47).withOpacity(0.35)),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFC99A47).withOpacity(0.08),
                  blurRadius: 10,
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFFC99A47).withOpacity(0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text(
                        'SUẤT DIỄN ĐÃ CHỌN',
                        style: TextStyle(
                          color: Color(0xFFE6C17A),
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                    const Spacer(),
                    if (widget.event.sessions.length > 1)
                      GestureDetector(
                        onTap: () => _showSessionSelectionSheet(),
                        child: const Row(
                          children: [
                            Text(
                              'Đổi suất diễn',
                              style: TextStyle(
                                color: Color(0xFF06B6D4),
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            SizedBox(width: 2),
                            Icon(Icons.keyboard_arrow_down_rounded, color: Color(0xFF06B6D4), size: 16),
                          ],
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  _formatShortDate(_selectedSession!.startTime),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.access_time_rounded, color: Color(0xFF06B6D4), size: 14),
                    const SizedBox(width: 5),
                    Text(
                      '${_formatSessionTime(_selectedSession!.startTime, _selectedSession!.endTime)} (Giờ Việt Nam)',
                      style: const TextStyle(color: Color(0xFF06B6D4), fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
                if (_selectedSession!.venue?.summary != null) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.location_on_outlined, color: Color(0xFF8B9CB5), size: 14),
                      const SizedBox(width: 5),
                      Expanded(
                        child: Text(
                          _selectedSession!.venue!.summary!,
                          style: const TextStyle(color: Color(0xFF8B9CB5), fontSize: 12),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 20),
        ],

        // 2. Ticket Selection or Seat Map
        if (_isLoadingSeats) ...[
          Container(
            padding: const EdgeInsets.symmetric(vertical: 40),
            alignment: Alignment.center,
            child: const Column(
              children: [
                CircularProgressIndicator(color: Color(0xFFE6C17A)),
                SizedBox(height: 12),
                Text(
                  'Đang tải sơ đồ ghế...',
                  style: TextStyle(color: Color(0xFF8B9CB5), fontSize: 13),
                ),
              ],
            ),
          ),
        ] else if (_hasSeatMap && _sessionSeats.isNotEmpty) ...[
          _buildSeatMapSection(ticketTypes),
        ] else ...[
          _buildUnseatedTicketList(ticketTypes),
        ],
        const SizedBox(height: 30),
      ],
    );
  }

  Widget _buildSeatMapSection(List<TicketTypeModel> ticketTypes) {
    final hasPositions = _sessionSeats.any((s) => s.xPosition != 0 || s.yPosition != 0);
    final positioned = hasPositions ? _sessionSeats : <SessionSeatItem>[];

    final config = _seatMapData?['config'] as Map<String, dynamic>? ?? {};
    final stagePosition = config['stagePosition'] ?? _seatMapData?['stage_position'];
    final hasStage = stagePosition != null && stagePosition != 'HIDDEN';
    final stageLabel = config['stageLabel']?.toString() ?? 'SÂN KHẤU';

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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Title
        const Row(
          children: [
            Icon(Icons.event_seat_rounded, color: Color(0xFFE6C17A), size: 18),
            SizedBox(width: 8),
            Text(
              'Chọn ghế trên sơ đồ',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 15,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        const Text(
          'Chạm vào ghế để chọn. Dùng 2 ngón tay hoặc nút phóng to để xem rõ hơn.',
          style: TextStyle(color: Color(0xFF8B9CB5), fontSize: 12),
        ),
        const SizedBox(height: 12),

        // Legends
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildLegendItem(const Color(0xFFE6C17A), 'Đang chọn'),
            const SizedBox(width: 16),
            _buildLegendItem(const Color(0xFF06B6D4), 'Còn trống', isBorderOnly: true),
            const SizedBox(width: 16),
            _buildLegendItem(const Color(0xFF334155), 'Đã bán/giữ'),
          ],
        ),
        const SizedBox(height: 10),

        // Ticket type color pills
        if (ticketTypes.isNotEmpty) ...[
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: ticketTypes.map((t) {
                final matchingSeat = _sessionSeats.firstWhere(
                  (s) =>
                      s.ticketTypeIds.contains(t.id) ||
                      (s.zoneName != null &&
                          s.zoneName!.trim().toLowerCase() == t.name.trim().toLowerCase()),
                  orElse: () => _sessionSeats.first,
                );
                final c = _getSeatColor(matchingSeat);
                return Container(
                  margin: const EdgeInsets.only(right: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF101932),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: c.withOpacity(0.5)),
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
                        '${t.name} (${t.formattedPrice})',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 14),
        ],

        // Canvas Viewport with Auto-Fit Overview
        LayoutBuilder(
          builder: (context, constraints) {
            final viewportW = constraints.maxWidth;
            const viewportH = 390.0;

            final scaleX = (viewportW - 16) / canvasW;
            final scaleY = (viewportH - 16) / canvasH;
            final fitScale = min(scaleX, scaleY).clamp(0.05, 1.0);

            final renderedW = canvasW * fitScale;
            final renderedH = canvasH * fitScale;
            final dx = max(0.0, (viewportW - renderedW) / 2);
            final dy = max(0.0, (viewportH - renderedH) / 2);

            final fitMatrix = Matrix4.identity()
              ..translate(dx, dy)
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
                border: Border.all(color: Colors.white.withOpacity(0.1)),
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
                                  color: const Color(0xFF1E3A8A).withOpacity(0.85),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: const Color(0xFF3B82F6), width: 1.5),
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(0xFF3B82F6).withOpacity(0.3),
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

                          // Seats (Absolute Positioned)
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

                  // Floating Zoom controls (at bottom-right so stage at top is not blocked)
                  Positioned(
                    right: 12,
                    bottom: 12,
                    child: Column(
                      children: [
                        _buildZoomButton(Icons.add, _zoomIn, 'Phóng to'),
                        const SizedBox(height: 6),
                        _buildZoomButton(Icons.restart_alt_rounded, _resetZoom, 'Căn giữa (Toàn cảnh)'),
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
                      '${seat.label} (${tt?.name ?? 'Vé'} - ${tt != null ? _formatCurrency(tt.price) : ''})',
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

        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Đã chọn: ${_selectedSeatIds.length} / 10 ghế',
              style: const TextStyle(
                color: Color(0xFF06B6D4),
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
            const Text(
              '(Tối đa 10 vé mỗi đơn)',
              style: TextStyle(color: Color(0xFF8B9CB5), fontSize: 11),
            ),
          ],
        ),
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
                    : zoneColor.withOpacity(0.8),
            width: isSelected ? 1.5 : 1.0,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: const Color(0xFFE6C17A).withOpacity(0.5),
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
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
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
            color: const Color(0xFF0F1A36).withOpacity(0.9),
            shape: BoxShape.circle,
            border: Border.all(color: const Color(0xFF06B6D4).withOpacity(0.4)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.4),
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

  Widget _buildUnseatedTicketList(List<TicketTypeModel> ticketTypes) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Icon(Icons.confirmation_number_outlined, color: Color(0xFFE6C17A), size: 18),
            SizedBox(width: 8),
            Text(
              'Chọn loại vé & số lượng',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 15,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        const Text(
          'Bạn có thể chọn kết hợp nhiều hạng vé khác nhau cho đơn đặt này.',
          style: TextStyle(color: Color(0xFF8B9CB5), fontSize: 12),
        ),
        const SizedBox(height: 14),

        ...ticketTypes.map((t) {
          final qty = _ticketQuantities[t.id] ?? 0;
          final isSoldOut = t.isSoldOut;
          final maxAllowed = t.availableQuantity > 0 ? t.availableQuantity.clamp(1, 10) : 10;
          final isSelected = qty > 0;

          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: isSelected ? const Color(0xFF141F3C) : const Color(0xFF101932),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isSelected
                    ? const Color(0xFFC99A47).withOpacity(0.8)
                    : Colors.white.withOpacity(0.08),
                width: isSelected ? 1.5 : 1,
              ),
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: const Color(0xFFC99A47).withOpacity(0.15),
                        blurRadius: 10,
                      ),
                    ]
                  : null,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Ticket Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        t.name,
                        style: TextStyle(
                          color: isSoldOut ? Colors.white38 : Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Text(
                            t.formattedPrice,
                            style: TextStyle(
                              color: isSoldOut ? Colors.white38 : const Color(0xFFFFB690),
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                          const SizedBox(width: 8),
                          if (isSoldOut)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.red.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text('Hết vé',
                                  style: TextStyle(color: Colors.redAccent, fontSize: 11, fontWeight: FontWeight.bold)),
                            )
                          else if (t.availableQuantity > 0)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFF06B6D4).withOpacity(0.12),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text('Còn ${t.availableQuantity} vé',
                                  style: const TextStyle(color: Color(0xFF06B6D4), fontSize: 11, fontWeight: FontWeight.w600)),
                            ),
                        ],
                      ),
                      if (t.description != null && t.description!.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          t.description!,
                          style: const TextStyle(color: Color(0xFF8B9CB5), fontSize: 12),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),

                const SizedBox(width: 12),

                // Quantity Stepper [- count +]
                if (isSoldOut)
                  const Text('Tạm ngưng', style: TextStyle(color: Colors.white38, fontSize: 12))
                else
                  Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFF0C142A),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: Colors.white.withOpacity(0.1)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Minus button
                        InkWell(
                          onTap: qty > 0
                              ? () {
                                  setState(() {
                                    _ticketQuantities[t.id] = qty - 1;
                                  });
                                }
                              : null,
                          borderRadius: BorderRadius.circular(20),
                          child: Container(
                            width: 32,
                            height: 32,
                            alignment: Alignment.center,
                            child: Icon(
                              Icons.remove_rounded,
                              size: 16,
                              color: qty > 0 ? Colors.white : Colors.white24,
                            ),
                          ),
                        ),

                        // Count
                        Container(
                          constraints: const BoxConstraints(minWidth: 26),
                          alignment: Alignment.center,
                          child: Text(
                            '$qty',
                            style: TextStyle(
                              color: qty > 0 ? const Color(0xFFE6C17A) : Colors.white70,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ),

                        // Plus button
                        InkWell(
                          onTap: qty < maxAllowed && _totalSelectedQuantity < 10
                              ? () {
                                  setState(() {
                                    _ticketQuantities[t.id] = qty + 1;
                                  });
                                }
                              : null,
                          borderRadius: BorderRadius.circular(20),
                          child: Container(
                            width: 32,
                            height: 32,
                            alignment: Alignment.center,
                            child: Icon(
                              Icons.add_rounded,
                              size: 16,
                              color: (qty < maxAllowed && _totalSelectedQuantity < 10)
                                  ? const Color(0xFF06B6D4)
                                  : Colors.white24,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          );
        }),

        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Đã chọn: $_totalSelectedQuantity / 10 vé',
              style: const TextStyle(color: Color(0xFF06B6D4), fontSize: 12, fontWeight: FontWeight.bold),
            ),
            const Text(
              '(Tối đa 10 vé mỗi đơn)',
              style: TextStyle(color: Color(0xFF8B9CB5), fontSize: 11),
            ),
          ],
        ),
        const SizedBox(height: 30),
      ],
    );
  }

  void _showSessionSelectionSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0A1024),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Chọn suất diễn',
                    style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white70, size: 20),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              ...widget.event.sessions.map((s) {
                final isSelected = _selectedSession?.id == s.id;
                return GestureDetector(
                  onTap: () {
                    Navigator.pop(ctx);
                    setState(() {
                      _selectedSession = s;
                      _initTicketQuantities();
                    });
                    _loadSessionSeats(s.id);
                  },
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: isSelected ? const Color(0xFF141F3C) : const Color(0xFF101932),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: isSelected ? const Color(0xFFC99A47) : Colors.white.withOpacity(0.08),
                        width: isSelected ? 1.5 : 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          isSelected ? Icons.check_circle_rounded : Icons.radio_button_off_rounded,
                          color: isSelected ? const Color(0xFFE6C17A) : Colors.white30,
                          size: 20,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _formatShortDate(s.startTime),
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                _formatSessionTime(s.startTime, s.endTime),
                                style: const TextStyle(color: Color(0xFF06B6D4), fontSize: 13),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ],
          ),
        );
      },
    );
  }

  // ==========================================
  // STEP 2: THÔNG TIN (NGƯỜI MUA & NGƯỜI THAM DỰ)
  // ==========================================
  Widget _buildStep2BuyerInfo() {
    final user = AuthService().currentUser;
    if (_buyerNameController.text.trim().isEmpty && user != null) {
      _buyerNameController.text = user.fullName;
    }
    if (_buyerEmailController.text.trim().isEmpty && user != null) {
      _buyerEmailController.text = user.email;
    }
    if (_buyerPhoneController.text.trim().isEmpty && user?.phone != null) {
      _buyerPhoneController.text = user!.phone!;
    }

    final bName = _buyerNameController.text.trim();
    final bEmail = _buyerEmailController.text.trim();
    if (_attendeeSlots.isNotEmpty && (bName.isNotEmpty || bEmail.isNotEmpty)) {
      final firstSlot = _attendeeSlots.first;
      if (firstSlot.nameController.text.trim().isEmpty && bName.isNotEmpty) {
        firstSlot.nameController.text = bName;
      }
      if (firstSlot.emailController.text.trim().isEmpty && bEmail.isNotEmpty) {
        firstSlot.emailController.text = bEmail;
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Buyer Card
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF101932),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withOpacity(0.08)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.person_pin_rounded, color: Color(0xFFE6C17A), size: 20),
                  SizedBox(width: 8),
                  Text(
                    'Thông tin người mua vé',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              const Text(
                'Vé điện tử và thông tin xác nhận đơn hàng sẽ được gửi về email này.',
                style: TextStyle(color: Color(0xFF8B9CB5), fontSize: 12),
              ),
              const SizedBox(height: 16),

              // Full Name
              _buildInputField(
                label: 'Họ và tên người mua *',
                controller: _buyerNameController,
                icon: Icons.person_outline_rounded,
                hintText: 'Ví dụ: Nguyễn Văn A',
              ),
              const SizedBox(height: 12),

              // Email
              _buildInputField(
                label: 'Email nhận vé *',
                controller: _buyerEmailController,
                icon: Icons.email_outlined,
                hintText: 'email@example.com',
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 12),

              // Phone
              _buildInputField(
                label: 'Số điện thoại liên hệ *',
                controller: _buyerPhoneController,
                icon: Icons.phone_outlined,
                hintText: '0901234567',
                keyboardType: TextInputType.phone,
              ),
            ],
          ),
        ),

        const SizedBox(height: 20),

        // Attendee Info Slots (if attendees exists)
        if (_attendeeSlots.isNotEmpty) ...[
          const Row(
            children: [
              Icon(Icons.groups_rounded, color: Color(0xFF06B6D4), size: 20),
              SizedBox(width: 8),
              Text(
                'Thông tin người tham dự',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            widget.event.requireAttendeeInfo == true
                ? 'Sự kiện yêu cầu điền danh sách người tham dự cho từng vé.'
                : 'Thông tin tham dự giúp ban tổ chức in tên vé và đối soát tại quầy check-in.',
            style: const TextStyle(color: Color(0xFF8B9CB5), fontSize: 12),
          ),
          const SizedBox(height: 12),

          ...List.generate(_attendeeSlots.length, (index) {
            final slot = _attendeeSlots[index];
            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF101932),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withOpacity(0.06)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFF06B6D4).withOpacity(0.12),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          slot.seatLabel != null
                              ? 'VÉ ${index + 1}: ${slot.ticketName.toUpperCase()} - GHẾ ${slot.seatLabel}'
                              : 'VÉ ${index + 1}: ${slot.ticketName.toUpperCase()}',
                          style: const TextStyle(
                            color: Color(0xFF06B6D4),
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _buildInputField(
                    label: 'Họ và tên người tham dự *',
                    controller: slot.nameController,
                    icon: Icons.person_outline,
                    hintText: 'Nhập tên người tham gia',
                  ),
                  const SizedBox(height: 10),
                  _buildInputField(
                    label: 'Email người tham dự *',
                    controller: slot.emailController,
                    icon: Icons.email_outlined,
                    hintText: 'email@example.com',
                    keyboardType: TextInputType.emailAddress,
                  ),
                ],
              ),
            );
          }),
        ],

        const SizedBox(height: 20),
      ],
    );
  }

  // ==========================================
  // STEP 3: KIỂM TRA ĐƠN HÀNG & MÃ KHUYẾN MÃI
  // ==========================================
  Widget _buildStep3ReviewOrder() {
    final types = _getAvailableTicketTypes();
    final selectedItems = types.where((t) => (_ticketQuantities[t.id] ?? 0) > 0).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. Mini Event Card
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFF101932),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withOpacity(0.08)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: SizedBox(
                  width: 76,
                  height: 76,
                  child: widget.event.coverImageUrl != null
                      ? Image.network(
                          widget.event.coverImageUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(color: Colors.white10),
                        )
                      : Container(color: Colors.white10),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.event.title,
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    if (_selectedSession != null) ...[
                      Row(
                        children: [
                          const Icon(Icons.calendar_today_outlined, color: Color(0xFF06B6D4), size: 12),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              _formatShortDate(_selectedSession!.startTime),
                              style: const TextStyle(color: Color(0xFF06B6D4), fontSize: 12, fontWeight: FontWeight.bold),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          const Icon(Icons.access_time_rounded, color: Color(0xFF8B9CB5), size: 12),
                          const SizedBox(width: 4),
                          Text(
                            _formatSessionTime(_selectedSession!.startTime, _selectedSession!.endTime),
                            style: const TextStyle(color: Color(0xFF8B9CB5), fontSize: 12),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // 2. Ticket breakdown card
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF101932),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.white.withOpacity(0.08)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.receipt_long_rounded, color: Color(0xFFE6C17A), size: 18),
                  SizedBox(width: 8),
                  Text(
                    'Chi tiết vé đã chọn',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              ...selectedItems.map((t) {
                final qty = _ticketQuantities[t.id] ?? 0;
                final lineTotal = t.price * qty;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          '${t.name} x $qty',
                          style: const TextStyle(color: Colors.white, fontSize: 13),
                        ),
                      ),
                      Text(
                        _formatCurrency(lineTotal),
                        style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                );
              }),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // 3. Buyer summary card
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF101932),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.white.withOpacity(0.08)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.person_pin_rounded, color: Color(0xFFE6C17A), size: 18),
                      SizedBox(width: 8),
                      Text(
                        'Thông tin người mua vé',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                    ],
                  ),
                  GestureDetector(
                    onTap: () => setState(() => _currentStep = 2),
                    child: const Text(
                      'Thay đổi',
                      style: TextStyle(color: Color(0xFF06B6D4), fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                _buyerNameController.text.trim().isNotEmpty
                    ? _buyerNameController.text.trim()
                    : 'Chưa nhập',
                style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(
                '${_buyerEmailController.text.trim().isNotEmpty ? _buyerEmailController.text.trim() : "Chưa nhập email"} • ${_buyerPhoneController.text.trim().isNotEmpty ? _buyerPhoneController.text.trim() : "Chưa nhập SĐT"}',
                style: const TextStyle(color: Color(0xFF8B9CB5), fontSize: 12),
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // 4. Attendees List Card (matching Web review step)
        if (_attendeeSlots.isNotEmpty) ...[
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF101932),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Colors.white.withOpacity(0.08)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.groups_rounded, color: Color(0xFF06B6D4), size: 18),
                        const SizedBox(width: 8),
                        Text(
                          'Thông tin người tham gia (${_attendeeSlots.length})',
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                      ],
                    ),
                    GestureDetector(
                      onTap: () => setState(() => _currentStep = 2),
                      child: const Text(
                        'Thay đổi',
                        style: TextStyle(color: Color(0xFF06B6D4), fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ...List.generate(_attendeeSlots.length, (idx) {
                  final slot = _attendeeSlots[idx];
                  final name = slot.nameController.text.trim();
                  final email = slot.emailController.text.trim();
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0C142A),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white.withOpacity(0.05)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFF06B6D4).withOpacity(0.12),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            slot.seatLabel != null
                                ? 'VÉ ${idx + 1}: ${slot.seatLabel}'
                                : 'VÉ ${idx + 1}',
                            style: const TextStyle(
                              color: Color(0xFF06B6D4),
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                name.isNotEmpty ? name : 'Chưa nhập họ tên',
                                style: TextStyle(
                                  color: name.isNotEmpty ? Colors.white : Colors.white38,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                email.isNotEmpty ? email : 'Chưa nhập email',
                                style: TextStyle(
                                  color: email.isNotEmpty ? const Color(0xFF8B9CB5) : Colors.white24,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],

        // 5. Promo code card with "Danh sách voucher" button (matching Web)
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF101932),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.white.withOpacity(0.08)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Row(
                      children: [
                        Icon(Icons.local_offer_outlined, color: Color(0xFFE6C17A), size: 18),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Mã giảm giá & Khuyến mãi',
                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13.5),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: _showVoucherSelectionModal,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                      decoration: BoxDecoration(
                        color: const Color(0xFF06B6D4).withOpacity(0.12),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFF06B6D4).withOpacity(0.3)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.confirmation_number_outlined, color: Color(0xFF06B6D4), size: 12),
                          const SizedBox(width: 4),
                          Text(
                            _availablePromos.isNotEmpty
                                ? 'Chọn voucher (${_availablePromos.length})'
                                : 'Chọn voucher',
                            style: const TextStyle(
                              color: Color(0xFF06B6D4),
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              Row(
                children: [
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFF0C142A),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white.withOpacity(0.1)),
                      ),
                      child: TextField(
                        controller: _promoController,
                        style: const TextStyle(color: Colors.white, fontSize: 13),
                        textCapitalization: TextCapitalization.characters,
                        decoration: const InputDecoration(
                          hintText: 'Nhập mã voucher / ưu đãi',
                          hintStyle: TextStyle(color: Color(0xFF8B9CB5), fontSize: 12),
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  ElevatedButton(
                    onPressed: () => _applyPromoCode(_promoController.text),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFC99A47),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                    child: const Text('Áp dụng', style: TextStyle(color: Color(0xFF070D1E), fontWeight: FontWeight.bold)),
                  ),
                ],
              ),

              // Applied Promo Badge
              if (_appliedPromoCode != null) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF06B6D4).withOpacity(0.12),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFF06B6D4).withOpacity(0.4)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.check_circle_rounded, color: Color(0xFF06B6D4), size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Mã $_appliedPromoCode đã áp dụng',
                              style: const TextStyle(color: Color(0xFF06B6D4), fontSize: 12, fontWeight: FontWeight.bold),
                            ),
                            if (_promoDiscountAmount > 0)
                              Text(
                                'Được giảm: -${_formatCurrency(_promoDiscountAmount)}',
                                style: const TextStyle(color: Color(0xFF34D399), fontSize: 12, fontWeight: FontWeight.bold),
                              )
                            else
                              const Text(
                                'Mã đã được lưu và sẽ đối soát khi thanh toán',
                                style: TextStyle(color: Color(0xFF8B9CB5), fontSize: 11),
                              ),
                          ],
                        ),
                      ),
                      GestureDetector(
                        onTap: _removePromoCode,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.red.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: Colors.red.withOpacity(0.3)),
                          ),
                          child: const Text(
                            'Hủy áp dụng',
                            style: TextStyle(color: Colors.redAccent, fontSize: 11, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),

        const SizedBox(height: 16),

        // 6. Event Policies & Terms Card (matching Web's "Điều khoản & Chính sách sự kiện")
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF101932),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.white.withOpacity(0.08)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.verified_user_outlined, color: Color(0xFF06B6D4), size: 18),
                  SizedBox(width: 8),
                  Text(
                    'Điều khoản & Chính sách sự kiện',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Attached Policy File (if any)
              if (widget.event.policyFileUrl != null && widget.event.policyFileUrl!.isNotEmpty) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF06B6D4).withOpacity(0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFF06B6D4).withOpacity(0.25)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF06B6D4).withOpacity(0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.file_present_rounded, color: Color(0xFF06B6D4), size: 20),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Tài liệu chính sách sự kiện',
                              style: TextStyle(color: Color(0xFF06B6D4), fontSize: 10, fontWeight: FontWeight.bold),
                            ),
                            Text(
                              widget.event.policyFileName ?? 'Chính sách sự kiện',
                              style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      TextButton.icon(
                        onPressed: () async {
                          final uri = Uri.tryParse(widget.event.policyFileUrl!);
                          if (uri != null && await canLaunchUrl(uri)) {
                            await launchUrl(uri, mode: LaunchMode.externalApplication);
                          }
                        },
                        icon: const Icon(Icons.open_in_new_rounded, size: 13, color: Color(0xFF06B6D4)),
                        label: const Text('Xem', style: TextStyle(color: Color(0xFF06B6D4), fontSize: 11, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
              ],

              // Terms and Conditions text (if any)
              if (widget.event.additionalTerms != null && widget.event.additionalTerms!.trim().isNotEmpty) ...[
                const Text(
                  'Chính sách & Quy định tham dự:',
                  style: TextStyle(color: Color(0xFF8B9CB5), fontSize: 11, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 6),
                Container(
                  width: double.infinity,
                  constraints: const BoxConstraints(maxHeight: 120),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0C142A),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.white.withOpacity(0.06)),
                  ),
                  child: SingleChildScrollView(
                    child: Text(
                      widget.event.additionalTerms!.trim(),
                      style: const TextStyle(color: Color(0xFFE2E8F0), fontSize: 12, height: 1.4),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
              ],

              // Refund Policy Breakdown (matching Web)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF0C142A),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white.withOpacity(0.06)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.sync_rounded, color: Color(0xFF06B6D4), size: 16),
                            SizedBox(width: 6),
                            Text(
                              'CHÍNH SÁCH HOÀN VÉ',
                              style: TextStyle(
                                color: Color(0xFF06B6D4),
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: widget.event.hasRefundPolicy
                                ? const Color(0xFF10B981).withOpacity(0.15)
                                : Colors.white.withOpacity(0.06),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: widget.event.hasRefundPolicy
                                  ? const Color(0xFF10B981).withOpacity(0.4)
                                  : Colors.white.withOpacity(0.15),
                            ),
                          ),
                          child: Text(
                            widget.event.hasRefundPolicy
                                ? 'Hỗ trợ hoàn vé có điều kiện'
                                : 'Không hỗ trợ hoàn hủy vé',
                            style: TextStyle(
                              color: widget.event.hasRefundPolicy
                                  ? const Color(0xFF34D399)
                                  : const Color(0xFF8B9CB5),
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    ...widget.event.refundPolicyLines.map((line) {
                      final isNote = line.startsWith('*');
                      if (isNote) {
                        return Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(
                            line,
                            style: const TextStyle(
                              color: Color(0xFF8B9CB5),
                              fontSize: 11,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        );
                      }
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              margin: const EdgeInsets.only(top: 5, right: 8),
                              width: 5,
                              height: 5,
                              decoration: BoxDecoration(
                                color: widget.event.hasRefundPolicy
                                    ? const Color(0xFF06B6D4)
                                    : const Color(0xFF64748B),
                                shape: BoxShape.circle,
                              ),
                            ),
                            Expanded(
                              child: Text(
                                line.replaceFirst(RegExp(r'^[•\-\*]\s*'), ''),
                                style: const TextStyle(
                                  color: Color(0xFFCBD5E1),
                                  fontSize: 12,
                                  height: 1.35,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                  ],
                ),
              ),

              const SizedBox(height: 14),

              // Mandatory Checkbox (matching Web)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 24,
                    height: 24,
                    child: Checkbox(
                      value: _termsAccepted,
                      activeColor: const Color(0xFFC99A47),
                      checkColor: const Color(0xFF070D1E),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                      side: BorderSide(
                        color: _termsAccepted ? const Color(0xFFC99A47) : Colors.white38,
                        width: 1.5,
                      ),
                      onChanged: (val) => setState(() => _termsAccepted = val ?? false),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _termsAccepted = !_termsAccepted),
                      child: RichText(
                        text: const TextSpan(
                          text: 'Tôi đã đọc và đồng ý với điều khoản tham dự và chính sách hoàn tiền của sự kiện này ',
                          style: TextStyle(color: Colors.white, fontSize: 12, height: 1.4),
                          children: [
                            TextSpan(
                              text: '*',
                              style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // 7. Total Price Breakdown
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF101932),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFC99A47).withOpacity(0.3)),
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Tạm tính:', style: TextStyle(color: Color(0xFF8B9CB5), fontSize: 13)),
                  Text(_formatCurrency(_subtotalPrice), style: const TextStyle(color: Colors.white, fontSize: 13)),
                ],
              ),
              if (_promoDiscountAmount > 0) ...[
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Giảm giá voucher:', style: TextStyle(color: Color(0xFF06B6D4), fontSize: 13)),
                    Text('-${_formatCurrency(_promoDiscountAmount)}',
                        style: const TextStyle(color: Color(0xFF06B6D4), fontSize: 13, fontWeight: FontWeight.bold)),
                  ],
                ),
              ],
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 10),
                child: Divider(color: Colors.white12, height: 1),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Tổng thanh toán:',
                      style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
                  Text(
                    _formatCurrency(_finalPrice),
                    style: const TextStyle(
                      color: Color(0xFFFFB690),
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 24),
      ],
    );
  }

  void _showVoucherSelectionModal() {
    final subtotal = _subtotalPrice;
    Map<String, dynamic>? tempSelected = _appliedPromo;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF101932),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (modalCtx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.75,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Chọn voucher sự kiện',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Chọn mã ưu đãi từ Ban tổ chức',
                            style: TextStyle(color: Color(0xFF8B9CB5), fontSize: 12),
                          ),
                        ],
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(modalCtx),
                        icon: const Icon(Icons.close_rounded, color: Colors.white70),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Voucher List
                  Flexible(
                    child: _availablePromos.isEmpty
                        ? const Center(
                            child: Padding(
                              padding: EdgeInsets.symmetric(vertical: 32),
                              child: Text(
                                'Sự kiện này chưa có mã giảm giá công khai.',
                                style: TextStyle(color: Color(0xFF8B9CB5), fontSize: 13, fontStyle: FontStyle.italic),
                              ),
                            ),
                          )
                        : ListView.separated(
                            shrinkWrap: true,
                            itemCount: _availablePromos.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 10),
                            itemBuilder: (c, idx) {
                              final p = _availablePromos[idx];
                              final code = p['code']?.toString() ?? '';
                              final minOrder = double.tryParse(p['min_order_value']?.toString() ?? '0') ?? 0.0;
                              final discountType = p['discount_type']?.toString().toUpperCase();
                              final discountVal = double.tryParse(p['discount_value']?.toString() ?? '0') ?? 0.0;
                              final maxDiscount = p['max_discount'] != null
                                  ? double.tryParse(p['max_discount'].toString())
                                  : null;
                              final endTime = p['end_time']?.toString();

                              String title = '';
                              if (discountType == 'PERCENTAGE') {
                                final capStr = maxDiscount != null && maxDiscount > 0
                                    ? ', tối đa ${_formatCurrency(maxDiscount)}'
                                    : '';
                                title = 'Giảm ${discountVal.toInt()}%$capStr';
                              } else {
                                title = 'Giảm ${_formatCurrency(discountVal)}';
                              }

                              final isUsable = subtotal >= minOrder;
                              final isSelected = tempSelected != null &&
                                  tempSelected!['code']?.toString().toUpperCase() == code.toUpperCase();

                              return GestureDetector(
                                onTap: () {
                                  if (!isUsable) return;
                                  setModalState(() {
                                    if (isSelected) {
                                      tempSelected = null;
                                    } else {
                                      tempSelected = p;
                                    }
                                  });
                                },
                                child: Container(
                                  padding: const EdgeInsets.all(14),
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? const Color(0xFFC99A47).withOpacity(0.15)
                                        : const Color(0xFF0C142A),
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(
                                      color: isSelected
                                          ? const Color(0xFFE6C17A)
                                          : Colors.white.withOpacity(isUsable ? 0.12 : 0.05),
                                      width: isSelected ? 1.5 : 1,
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              title,
                                              style: TextStyle(
                                                color: isUsable ? Colors.white : Colors.white38,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 14,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Row(
                                              children: [
                                                const Text('Mã: ', style: TextStyle(color: Color(0xFF8B9CB5), fontSize: 12)),
                                                Text(
                                                  code,
                                                  style: TextStyle(
                                                    color: isUsable ? const Color(0xFFE6C17A) : Colors.white38,
                                                    fontWeight: FontWeight.bold,
                                                    fontFamily: 'monospace',
                                                    fontSize: 13,
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              'Đơn tối thiểu: ${_formatCurrency(minOrder)}',
                                              style: TextStyle(
                                                color: isUsable ? const Color(0xFF8B9CB5) : Colors.white24,
                                                fontSize: 11,
                                              ),
                                            ),
                                            if (endTime != null) ...[
                                              const SizedBox(height: 2),
                                              Text(
                                                'HSD: ${_formatShortDate(endTime)}',
                                                style: const TextStyle(color: Color(0xFFE6C17A), fontSize: 11),
                                              ),
                                            ],
                                            if (!isUsable) ...[
                                              const SizedBox(height: 4),
                                              const Text(
                                                'Đơn hàng chưa đủ điều kiện áp dụng',
                                                style: TextStyle(color: Color(0xFFF43F5E), fontSize: 11, fontWeight: FontWeight.bold),
                                              ),
                                            ],
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Container(
                                        width: 24,
                                        height: 24,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: isSelected ? const Color(0xFFE6C17A) : Colors.transparent,
                                          border: Border.all(
                                            color: isSelected ? const Color(0xFFE6C17A) : Colors.white30,
                                            width: 2,
                                          ),
                                        ),
                                        child: isSelected
                                            ? const Icon(Icons.check, size: 16, color: Color(0xFF070D1E))
                                            : null,
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                  ),

                  const SizedBox(height: 16),

                  // Apply button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(modalCtx);
                        if (tempSelected != null) {
                          final code = tempSelected!['code']?.toString() ?? '';
                          _applyPromoCode(code);
                        } else {
                          _removePromoCode();
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFC99A47),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      child: const Text(
                        'Áp dụng',
                        style: TextStyle(color: Color(0xFF070D1E), fontWeight: FontWeight.bold, fontSize: 15),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showTicketSummaryBottomSheet() {
    setState(() => _isSummarySheetOpen = true);
    final types = _getAvailableTicketTypes();
    final selectedItems = types.where((t) => (_ticketQuantities[t.id] ?? 0) > 0).toList();

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0C142A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header: Thông tin đặt vé & Chọn lại vé (matching web & Image 2)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Thông tin đặt vé',
                    style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  GestureDetector(
                    onTap: () {
                      Navigator.pop(ctx);
                      if (_currentStep != 1) {
                        setState(() => _currentStep = 1);
                      }
                    },
                    child: const Text(
                      'Chọn lại vé',
                      style: TextStyle(
                        color: Color(0xFF06B6D4),
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Columns title
              const Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Loại vé', style: TextStyle(color: Color(0xFF8B9CB5), fontSize: 12, fontWeight: FontWeight.w600)),
                  Text('Số lượng', style: TextStyle(color: Color(0xFF8B9CB5), fontSize: 12, fontWeight: FontWeight.w600)),
                ],
              ),
              const SizedBox(height: 8),
              const Divider(color: Colors.white12, height: 1),
              const SizedBox(height: 12),

              // Ticket rows
              if (selectedItems.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Center(
                    child: Text('Chưa có vé nào được chọn', style: TextStyle(color: Colors.white38, fontSize: 13)),
                  ),
                )
              else
                ...selectedItems.map((t) {
                  final qty = _ticketQuantities[t.id] ?? 0;
                  final lineTotal = t.price * qty;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                t.name,
                                style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                _formatCurrency(t.price),
                                style: const TextStyle(color: Color(0xFF8B9CB5), fontSize: 12),
                              ),
                              if (_hasSeatMap && _selectedSeats.isNotEmpty) ...[
                                Builder(
                                  builder: (_) {
                                    final seatsForType = _selectedSeats.where((s) {
                                      final tt = _getTicketTypeForSeat(s);
                                      return tt?.id == t.id;
                                    }).toList();
                                    if (seatsForType.isEmpty) return const SizedBox.shrink();
                                    return Padding(
                                      padding: const EdgeInsets.only(top: 4),
                                      child: Wrap(
                                        spacing: 4,
                                        runSpacing: 4,
                                        children: seatsForType.map((s) {
                                          return Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFFC99A47).withOpacity(0.2),
                                              borderRadius: BorderRadius.circular(4),
                                              border: Border.all(color: const Color(0xFFC99A47).withOpacity(0.6)),
                                            ),
                                            child: Text(
                                              s.label,
                                              style: const TextStyle(
                                                color: Color(0xFFE6C17A),
                                                fontSize: 10,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          );
                                        }).toList(),
                                      ),
                                    );
                                  },
                                ),
                              ],
                            ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              qty.toString().padLeft(2, '0'),
                              style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _formatCurrency(lineTotal),
                              style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                }),

              const Divider(color: Colors.white12, height: 1),
              const SizedBox(height: 12),

              // Tạm tính
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Tạm tính', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)),
                  Text(
                    _formatCurrency(_subtotalPrice),
                    style: const TextStyle(color: Color(0xFF06B6D4), fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ],
              ),

              if (_currentStep == 3 && _promoDiscountAmount > 0) ...[
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Giảm giá', style: TextStyle(color: Color(0xFF06B6D4), fontSize: 13)),
                    Text('-${_formatCurrency(_promoDiscountAmount)}',
                        style: const TextStyle(color: Color(0xFF06B6D4), fontSize: 13, fontWeight: FontWeight.bold)),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Tổng thanh toán',
                      style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      _formatCurrency(_finalPrice),
                      style: const TextStyle(color: Color(0xFFFFB690), fontSize: 17, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 12),
              const Center(
                child: Text(
                  'Vui lòng điền thông tin để tiếp tục',
                  style: TextStyle(color: Color(0xFF8B9CB5), fontSize: 11),
                ),
              ),
              const SizedBox(height: 12),
              const Divider(color: Colors.white12, height: 1),
              const SizedBox(height: 12),

              // Bottom action row inside sheet (matching Image 2)
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => Navigator.pop(ctx),
                      behavior: HitTestBehavior.opaque,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _currentStep == 3 ? 'Tổng tiền' : 'Tạm tính ($_totalSelectedQuantity vé)',
                            style: const TextStyle(color: Color(0xFF8B9CB5), fontSize: 11),
                          ),
                          const SizedBox(height: 2),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                _formatCurrency(_currentStep == 3 ? _finalPrice : _subtotalPrice),
                                style: const TextStyle(
                                  color: Color(0xFF06B6D4),
                                  fontSize: 18,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              const SizedBox(width: 4),
                              const Icon(
                                Icons.keyboard_arrow_down_rounded,
                                color: Color(0xFF06B6D4),
                                size: 20,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.pop(ctx);
                      if (_currentStep == 1 && _totalSelectedQuantity > 0) {
                        _goToStep2();
                      } else if (_currentStep == 2) {
                        _goToStep3();
                      } else if (_currentStep == 3 && !_isCheckingOut) {
                        _handleCheckout();
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFE6C17A),
                      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                    ),
                    child: Text(
                      _currentStep == 3 ? 'Thanh toán' : 'Tiếp tục',
                      style: const TextStyle(
                        color: Color(0xFF070D1E),
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    ).whenComplete(() {
      if (mounted) {
        setState(() => _isSummarySheetOpen = false);
      }
    });
  }

  Widget _buildBottomBar() {
    final double displayAmount = _currentStep == 3 ? _finalPrice : _subtotalPrice;
    final String label = _currentStep == 3 ? 'Tổng thanh toán' : 'Tạm tính ($_totalSelectedQuantity vé)';
    final String buttonText = _currentStep == 1
        ? 'Tiếp tục'
        : _currentStep == 2
            ? 'Tiếp tục'
            : 'Thanh toán';
    final VoidCallback? onButtonTap = _currentStep == 1
        ? (_totalSelectedQuantity > 0 ? _goToStep2 : null)
        : _currentStep == 2
            ? _goToStep3
            : (_isCheckingOut ? null : _handleCheckout);

    return Container(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 12,
        bottom: MediaQuery.of(context).padding.bottom + 12,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFF0C142A),
        border: Border(top: BorderSide(color: Colors.white.withOpacity(0.08))),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.6),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Row(
        children: [
          // Left: Price + Expand arrow
          Expanded(
            child: GestureDetector(
              onTap: _showTicketSummaryBottomSheet,
              behavior: HitTestBehavior.opaque,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(color: Color(0xFF8B9CB5), fontSize: 11),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _formatCurrency(displayAmount),
                        style: const TextStyle(
                          color: Color(0xFFFFB690),
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        _isSummarySheetOpen
                            ? Icons.keyboard_arrow_down_rounded
                            : Icons.keyboard_arrow_up_rounded,
                        color: const Color(0xFFE6C17A),
                        size: 20,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(width: 12),

          // Right: Button "Tiếp tục" / "Thanh toán"
          ElevatedButton(
            onPressed: onButtonTap,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFE6C17A),
              disabledBackgroundColor: const Color(0xFF1E2846),
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              elevation: onButtonTap != null ? 6 : 0,
            ),
            child: _isCheckingOut && _currentStep == 3
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF070D1E)),
                  )
                : Text(
                    buttonText,
                    style: TextStyle(
                      color: onButtonTap != null ? const Color(0xFF070D1E) : Colors.white24,
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputField({
    required String label,
    required TextEditingController controller,
    required IconData icon,
    String? hintText,
    TextInputType? keyboardType,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0C142A),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        style: const TextStyle(color: Colors.white, fontSize: 13),
        decoration: InputDecoration(
          prefixIcon: Icon(icon, color: const Color(0xFF06B6D4), size: 18),
          labelText: label,
          labelStyle: const TextStyle(color: Color(0xFF8B9CB5), fontSize: 12),
          hintText: hintText,
          hintStyle: const TextStyle(color: Colors.white24, fontSize: 12),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        ),
      ),
    );
  }
}
