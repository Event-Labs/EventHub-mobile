import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../core/api/auth_service.dart';
import '../../../../core/api/waiting_room_service.dart';
import '../../../../core/models/event_model.dart';
import '../../../../core/models/waiting_room_model.dart';
import '../../../../core/theme/app_colors.dart';
import 'ticket_booking_page.dart';

class WaitingRoomPage extends StatefulWidget {
  final EventModel event;
  final String? selectedSessionId;

  const WaitingRoomPage({
    super.key,
    required this.event,
    this.selectedSessionId,
  });

  @override
  State<WaitingRoomPage> createState() => _WaitingRoomPageState();
}

class _WaitingRoomPageState extends State<WaitingRoomPage> with SingleTickerProviderStateMixin {
  final WaitingRoomService _waitingRoomService = WaitingRoomService();

  WaitingRoomStatus _status = WaitingRoomStatus.loading;
  int _position = 0;
  int? _initialPosition;
  int _totalWaiting = 0;
  int _estimatedWaitSeconds = 0;
  int _pollIntervalMs = 3000;
  int _admittedSecondsLeft = 600;
  String? _sessionId;
  String? _bookingToken;
  bool _isReconnecting = false;

  Timer? _pollTimer;
  Timer? _countdownTimer;
  Timer? _autoRedirectTimer;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _initQueue();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _countdownTimer?.cancel();
    _autoRedirectTimer?.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _initQueue() async {
    setState(() => _status = WaitingRoomStatus.loading);
    try {
      final res = await _waitingRoomService.joinQueue(widget.event.id);

      if (!mounted) return;

      if (res.isDirectAccess) {
        _proceedToBooking();
        return;
      }

      _sessionId = res.sessionId;
      _applyQueueState(res);

      if (_status == WaitingRoomStatus.waiting || _status == WaitingRoomStatus.nearTurn) {
        _startPolling();
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _status = WaitingRoomStatus.connectionLost);
      _startPolling();
    }
  }

  void _applyQueueState(WaitingRoomModel data) {
    if (data.isAdmitted) {
      _handleAdmitted(data);
    } else if (data.isWaiting) {
      _handleQueued(data);
    } else if (data.isSoldOut) {
      _pollTimer?.cancel();
      setState(() => _status = WaitingRoomStatus.soldOut);
    } else if (data.isExpired) {
      _pollTimer?.cancel();
      setState(() => _status = WaitingRoomStatus.expired);
    } else if (data.isPaused) {
      setState(() => _status = WaitingRoomStatus.paused);
    }
  }

  void _handleQueued(WaitingRoomModel data) {
    setState(() {
      _position = data.position;
      if (_initialPosition == null || data.position > _initialPosition!) {
        _initialPosition = data.position;
      }
      _totalWaiting = data.totalWaiting > 0 ? data.totalWaiting : (data.position + 1);
      _estimatedWaitSeconds = data.estimatedWaitSeconds;
      _pollIntervalMs = data.pollIntervalMs;
      _status = (data.isNearTurn || data.position <= 5)
          ? WaitingRoomStatus.nearTurn
          : WaitingRoomStatus.waiting;
      _isReconnecting = false;
    });
  }

  void _handleAdmitted(WaitingRoomModel data) {
    _pollTimer?.cancel();
    setState(() {
      _status = WaitingRoomStatus.admitted;
      _bookingToken = data.bookingToken;
      _admittedSecondsLeft = data.remainingSeconds > 0 ? data.remainingSeconds : 600;
    });

    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      setState(() {
        if (_admittedSecondsLeft <= 1) {
          timer.cancel();
          _status = WaitingRoomStatus.expired;
          _admittedSecondsLeft = 0;
        } else {
          _admittedSecondsLeft--;
        }
      });
    });

    _autoRedirectTimer?.cancel();
    _autoRedirectTimer = Timer(const Duration(milliseconds: 2500), () {
      if (mounted && _status == WaitingRoomStatus.admitted) {
        _proceedToBooking();
      }
    });
  }

  void _startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(Duration(milliseconds: _pollIntervalMs), (timer) async {
      if (!mounted || _sessionId == null) return;
      if (_status != WaitingRoomStatus.waiting &&
          _status != WaitingRoomStatus.nearTurn &&
          _status != WaitingRoomStatus.connectionLost) {
        timer.cancel();
        return;
      }

      try {
        final res = await _waitingRoomService.getQueueStatus(widget.event.id, _sessionId!);
        if (!mounted) return;
        _applyQueueState(res);
      } catch (_) {
        if (!mounted) return;
        setState(() {
          _status = WaitingRoomStatus.connectionLost;
          _isReconnecting = true;
        });
      }
    });
  }

  void _proceedToBooking() {
    _pollTimer?.cancel();
    _countdownTimer?.cancel();
    _autoRedirectTimer?.cancel();

    final user = AuthService().currentUser;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => TicketBookingPage(
          event: widget.event,
          initialSessionId: widget.selectedSessionId,
          initialBuyerName: user?.fullName,
          initialBuyerEmail: user?.email,
          initialBuyerPhone: user?.phone,
          bookingToken: _bookingToken,
        ),
      ),
    );
  }

  Future<void> _handleLeave() async {
    if (_status == WaitingRoomStatus.waiting || _status == WaitingRoomStatus.nearTurn) {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: const Color(0xFF0F172A),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(color: AppColors.gold.withOpacity(0.4)),
          ),
          title: const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: AppColors.goldLight),
              SizedBox(width: 8),
              Text(
                'Rời phòng chờ?',
                style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          content: const Text(
            'Nếu rời đi, bạn sẽ mất vị trí xếp hàng hiện tại và phải xếp hàng lại từ đầu.',
            style: TextStyle(color: Colors.white70, fontSize: 13, height: 1.4),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Ở lại xếp hàng', style: TextStyle(color: Colors.white60)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent.shade700,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Xác nhận rời'),
            ),
          ],
        ),
      );

      if (confirm != true) return;
    }

    if (_sessionId != null) {
      _waitingRoomService.leaveQueue(widget.event.id, _sessionId!).catchError((_) => false);
    }

    if (mounted) {
      Navigator.pop(context);
    }
  }

  Future<void> _handleRetry() async {
    await _waitingRoomService.clearSavedSession(widget.event.id);
    await _waitingRoomService.clearBookingToken(widget.event.id);
    _sessionId = null;
    _initialPosition = null;
    _initQueue();
  }

  double get _progressPercent {
    if (_status == WaitingRoomStatus.admitted) return 1.0;
    if (_initialPosition != null && _initialPosition! > 0) {
      final p = (_initialPosition! - _position) / _initialPosition!;
      return p.clamp(0.05, 0.95);
    }
    return 0.1;
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        await _handleLeave();
        return false;
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF030712),
        body: Stack(
          children: [
            // Ambient Radial Gradients
            Positioned(
              top: -100,
              left: 0,
              right: 0,
              height: 350,
              child: Container(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: Alignment.topCenter,
                    radius: 0.9,
                    colors: [
                      AppColors.gold.withOpacity(0.18),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              bottom: -50,
              right: -50,
              width: 300,
              height: 300,
              child: Container(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: Alignment.center,
                    radius: 0.8,
                    colors: [
                      AppColors.primaryContainer.withOpacity(0.12),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),

            SafeArea(
              child: Column(
                children: [
                  _buildHeader(),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      child: Column(
                        children: [
                          const SizedBox(height: 10),
                          _buildConcertBusIllustration(),
                          const SizedBox(height: 18),
                          _buildMainCard(),
                          const SizedBox(height: 20),
                          _buildBackButton(),
                          const SizedBox(height: 16),
                          const Text(
                            '© 2026 EventHub Operations Platform • Secure Virtual Waiting Room',
                            style: TextStyle(color: Colors.white30, fontSize: 10),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 10),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF081126).withOpacity(0.85),
        border: Border(bottom: BorderSide(color: Colors.white.withOpacity(0.08))),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppColors.gold.withOpacity(0.15),
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.gold.withOpacity(0.3)),
                ),
                child: const Icon(Icons.confirmation_number_outlined, color: AppColors.goldLight, size: 18),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.goldLight.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.goldLight.withOpacity(0.3)),
                ),
                child: const Text(
                  'PHÒNG CHỜ ẢO',
                  style: TextStyle(
                    color: AppColors.goldLight,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
            ],
          ),
          InkWell(
            onTap: _handleLeave,
            borderRadius: BorderRadius.circular(20),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.06),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white.withOpacity(0.12)),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.arrow_back_ios_new, size: 12, color: AppColors.goldLight),
                  SizedBox(width: 4),
                  Text(
                    'Quay lại',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
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

  Widget _buildConcertBusIllustration() {
    return SizedBox(
      height: 90,
      width: 180,
      child: CustomPaint(
        painter: _ConcertBusPainter(),
      ),
    );
  }

  Widget _buildMainCard() {
    final isNear = _status == WaitingRoomStatus.nearTurn;
    final isAdmitted = _status == WaitingRoomStatus.admitted;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFF0A1128).withOpacity(0.85),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: isAdmitted
              ? const Color(0xFF10B981).withOpacity(0.7)
              : isNear
                  ? AppColors.goldLight.withOpacity(0.7)
                  : Colors.white.withOpacity(0.1),
          width: isAdmitted || isNear ? 1.8 : 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: isAdmitted
                ? Colors.greenAccent.withOpacity(0.2)
                : isNear
                    ? AppColors.gold.withOpacity(0.25)
                    : Colors.black.withOpacity(0.6),
            blurRadius: isAdmitted || isNear ? 28 : 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 24),
      child: Column(
        children: [
          if (_status == WaitingRoomStatus.connectionLost || _isReconnecting)
            _buildConnectionBanner(),

          // Event Title
          Text(
            widget.event.title.toUpperCase(),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.8,
              height: 1.3,
            ),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 16),

          // Dynamic State Content
          if (_status == WaitingRoomStatus.waiting ||
              _status == WaitingRoomStatus.nearTurn ||
              _status == WaitingRoomStatus.loading ||
              _status == WaitingRoomStatus.connectionLost)
            _buildWaitingSection()
          else if (_status == WaitingRoomStatus.admitted)
            _buildAdmittedSection()
          else if (_status == WaitingRoomStatus.soldOut)
            _buildSoldOutSection()
          else if (_status == WaitingRoomStatus.expired)
            _buildExpiredSection()
          else if (_status == WaitingRoomStatus.paused)
            _buildPausedSection(),

          // Event Poster Thumbnail
          if (widget.event.coverImageUrl != null && widget.event.coverImageUrl!.isNotEmpty)
            _buildEventPoster(),
        ],
      ),
    );
  }

  Widget _buildConnectionBanner() {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.amber.shade900.withOpacity(0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.amber.withOpacity(0.4)),
      ),
      child: const Row(
        children: [
          Icon(Icons.wifi_off_rounded, color: Colors.amberAccent, size: 16),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              'Đang tự động kết nối lại... Vị trí của bạn được giữ nguyên.',
              style: TextStyle(color: Colors.amberAccent, fontSize: 11, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWaitingSection() {
    return Column(
      children: [
        const Text(
          'SỐ NGƯỜI ĐANG XẾP HÀNG TRƯỚC BẠN',
          style: TextStyle(
            color: Colors.white60,
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.5,
          ),
        ),
        const SizedBox(height: 12),

        // Big Position Number
        if (_status == WaitingRoomStatus.loading)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: CircularProgressIndicator(color: AppColors.goldLight),
          )
        else
          ShaderMask(
            shaderCallback: (bounds) => const LinearGradient(
              colors: [Color(0xFFFDE047), Color(0xFFE6C17A), Color(0xFFC99A47)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ).createShader(bounds),
            child: Text(
              NumberFormat.decimalPattern('vi_VN').format(_position),
              style: const TextStyle(
                fontSize: 60,
                fontWeight: FontWeight.w900,
                color: Colors.white,
                letterSpacing: -1.0,
                height: 1.0,
              ),
            ),
          ),

        // Near Turn Banner
        if (_status == WaitingRoomStatus.nearTurn)
          ScaleTransition(
            scale: _pulseAnimation,
            child: Container(
              margin: const EdgeInsets.only(top: 14, bottom: 4),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFC99A47), Color(0xFFE6C17A)],
                ),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.gold.withOpacity(0.4),
                    blurRadius: 16,
                  ),
                ],
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.auto_awesome, color: Color(0xFF0D1B2A), size: 16),
                  SizedBox(width: 6),
                  Text(
                    'Sắp đến lượt của bạn! Hãy chuẩn bị chọn vé.',
                    style: TextStyle(
                      color: Color(0xFF0D1B2A),
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ),
          ),

        const SizedBox(height: 16),

        // Progress Bar
        _buildProgressBar(),

        const SizedBox(height: 18),

        // Guidance & Estimated Wait
        const Text(
          'Đừng thoát ứng dụng, bạn sẽ mất lượt mua vé.',
          style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w600),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 4),
        const Text(
          'Bạn có 10 phút để đặt vé và 5 phút để thanh toán.',
          style: TextStyle(color: Colors.white38, fontSize: 11),
          textAlign: TextAlign.center,
        ),
        if (_estimatedWaitSeconds > 0) ...[
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.schedule, color: AppColors.goldLight, size: 14),
              const SizedBox(width: 4),
              Text(
                'Thời gian chờ dự kiến: ~${(_estimatedWaitSeconds / 60).ceil()} phút',
                style: const TextStyle(
                  color: AppColors.goldLight,
                  fontSize: 11.5,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildProgressBar() {
    return Column(
      children: [
        Stack(
          alignment: Alignment.centerLeft,
          children: [
            Container(
              height: 8,
              width: double.infinity,
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B),
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            FractionallySizedBox(
              widthFactor: _progressPercent,
              child: Container(
                height: 8,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF8C6D23), Color(0xFFC99A47), Color(0xFFE6C17A)],
                  ),
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.gold.withOpacity(0.6),
                      blurRadius: 8,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildAdmittedSection() {
    return Column(
      children: [
        ScaleTransition(
          scale: _pulseAnimation,
          child: Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: const Color(0xFF10B981).withOpacity(0.2),
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFF10B981).withOpacity(0.6), width: 2),
              boxShadow: [
                BoxShadow(
                  color: Colors.greenAccent.withOpacity(0.35),
                  blurRadius: 20,
                ),
              ],
            ),
            child: const Icon(Icons.check_circle_rounded, color: Color(0xFF34D399), size: 44),
          ),
        ),
        const SizedBox(height: 14),
        ShaderMask(
          shaderCallback: (bounds) => const LinearGradient(
            colors: [Color(0xFFFDE047), Color(0xFFE6C17A), Color(0xFFC99A47)],
          ).createShader(bounds),
          child: const Text(
            'ĐÃ ĐẾN LƯỢT CỦA BẠN!',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              color: Colors.white,
              letterSpacing: 0.5,
            ),
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'Bạn đã được cấp quyền vào khu vực đặt vé.',
          style: TextStyle(color: Colors.white70, fontSize: 12),
        ),
        const SizedBox(height: 16),

        // Countdown Box
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.45),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.gold.withOpacity(0.4)),
          ),
          child: Column(
            children: [
              const Text(
                'Thời gian còn lại để đặt vé',
                style: TextStyle(color: Colors.white60, fontSize: 11, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 4),
              Text(
                WaitingRoomModel.formatCountdown(_admittedSecondsLeft),
                style: const TextStyle(
                  color: AppColors.goldLight,
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                  fontFamily: 'monospace',
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),

        // Action Button
        ElevatedButton(
          onPressed: _proceedToBooking,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.gold,
            foregroundColor: const Color(0xFF0D1B2A),
            elevation: 8,
            shadowColor: AppColors.gold.withOpacity(0.5),
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.shopping_bag_outlined, color: Color(0xFF0D1B2A), size: 18),
              SizedBox(width: 8),
              Text(
                'TIẾN HÀNH CHỌN VÉ NGAY',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900, letterSpacing: 0.5),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Tự động chuyển hướng trong giây lát...',
          style: TextStyle(color: Colors.white38, fontSize: 10.5),
        ),
      ],
    );
  }

  Widget _buildSoldOutSection() {
    return Column(
      children: [
        Container(
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            color: Colors.redAccent.withOpacity(0.18),
            shape: BoxShape.circle,
            border: Border.all(color: Colors.redAccent.withOpacity(0.4)),
          ),
          child: const Icon(Icons.confirmation_number_outlined, color: Colors.redAccent, size: 32),
        ),
        const SizedBox(height: 12),
        const Text(
          'SỰ KIỆN ĐÃ BÁN HẾT VÉ',
          style: TextStyle(color: Colors.redAccent, fontSize: 16, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 6),
        const Text(
          'Toàn bộ số lượng vé của sự kiện đã được đặt hết. Cảm ơn sự quan tâm của bạn.',
          style: TextStyle(color: Colors.white70, fontSize: 12),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),
        ElevatedButton(
          onPressed: () => Navigator.pop(context),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.gold,
            foregroundColor: const Color(0xFF0D1B2A),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          ),
          child: const Text('Quay về trang sự kiện', style: TextStyle(fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }

  Widget _buildExpiredSection() {
    return Column(
      children: [
        Container(
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            color: Colors.amber.withOpacity(0.18),
            shape: BoxShape.circle,
            border: Border.all(color: Colors.amber.withOpacity(0.4)),
          ),
          child: const Icon(Icons.alarm_off_rounded, color: Colors.amberAccent, size: 32),
        ),
        const SizedBox(height: 12),
        const Text(
          'PHIÊN CHỜ ĐÃ HẾT HẠN',
          style: TextStyle(color: AppColors.goldLight, fontSize: 16, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 6),
        const Text(
          'Phiên phòng chờ của bạn đã hết hạn do quá thời gian giữ lượt hoặc không thao tác.',
          style: TextStyle(color: Colors.white70, fontSize: 12),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),
        ElevatedButton(
          onPressed: _handleRetry,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.gold,
            foregroundColor: const Color(0xFF0D1B2A),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          ),
          child: const Text('Xếp hàng lại', style: TextStyle(fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }

  Widget _buildPausedSection() {
    return Column(
      children: [
        const Icon(Icons.pause_circle_outline, color: AppColors.goldLight, size: 48),
        const SizedBox(height: 12),
        const Text(
          'HÀNG ĐỢI ĐANG TẠM DỪNG',
          style: TextStyle(color: AppColors.goldLight, fontSize: 16, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 6),
        const Text(
          'Ban tổ chức đang tạm dừng nhận lượt mới. Vui lòng giữ màn hình này, hệ thống sẽ mở lại sớm.',
          style: TextStyle(color: Colors.white70, fontSize: 12),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildEventPoster() {
    return Container(
      margin: const EdgeInsets.only(top: 20),
      height: 110,
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.12)),
        image: DecorationImage(
          image: NetworkImage(widget.event.coverImageUrl!),
          fit: BoxFit.cover,
        ),
      ),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            begin: Alignment.bottomCenter,
            end: Alignment.topCenter,
            colors: [
              Colors.black.withOpacity(0.85),
              Colors.transparent,
            ],
          ),
        ),
        padding: const EdgeInsets.all(10),
        alignment: Alignment.bottomLeft,
        child: Text(
          widget.event.title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 11,
            fontWeight: FontWeight.bold,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }

  Widget _buildBackButton() {
    return OutlinedButton(
      onPressed: _handleLeave,
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.goldLight,
        side: BorderSide(color: AppColors.gold.withOpacity(0.6)),
        backgroundColor: Colors.black.withOpacity(0.5),
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      ),
      child: const Text(
        'Quay về',
        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 0.5),
      ),
    );
  }
}

/// Custom Painter drawing the EventHub Signature Concert Bus Illustration
class _ConcertBusPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final scaleX = size.width / 200.0;
    final scaleY = size.height / 100.0;
    canvas.scale(scaleX, scaleY);

    // Road shadow
    final shadowPaint = Paint()..color = Colors.black.withOpacity(0.6);
    canvas.drawOval(const Rect.fromLTWH(15, 84, 170, 8), shadowPaint);

    // Bus body
    final bodyPaint = Paint()..color = const Color(0xFF0C1446);
    final borderPaint = Paint()
      ..color = const Color(0xFFC99A47)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    final busRect = RRect.fromRectAndRadius(
      const Rect.fromLTWH(35, 35, 130, 42),
      const Radius.circular(14),
    );
    canvas.drawRRect(busRect, bodyPaint);
    canvas.drawRRect(busRect, borderPaint);

    // Bus Windows
    final windowPaint = Paint()..color = const Color(0xFF1E293B);
    final windowRect = RRect.fromRectAndRadius(
      const Rect.fromLTWH(42, 40, 116, 18),
      const Radius.circular(6),
    );
    canvas.drawRRect(windowRect, windowPaint);

    // Concert fans heads inside windows
    final fanPaints = [
      Paint()..color = const Color(0xFF10B981), // Green
      Paint()..color = const Color(0xFFF59E0B), // Amber
      Paint()..color = const Color(0xFFE6C17A), // Gold Light
      Paint()..color = const Color(0xFF38BDF8), // Sky Blue
    ];
    final fanPositions = [58.0, 82.0, 106.0, 130.0];
    for (int i = 0; i < fanPositions.length; i++) {
      canvas.drawCircle(Offset(fanPositions[i], 48), 6, fanPaints[i]);
    }

    // Headlights
    final headlightFront = Paint()..color = const Color(0xFFFDE047);
    final headlightBack = Paint()..color = const Color(0xFFEF4444);
    canvas.drawCircle(const Offset(160, 62), 4.5, headlightFront);
    canvas.drawCircle(const Offset(40, 62), 4.5, headlightBack);

    // Wheels
    final wheelTire = Paint()..color = const Color(0xFF020617);
    final wheelRim = Paint()
      ..color = const Color(0xFF64748B)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    final wheelHub = Paint()..color = const Color(0xFFE6C17A);

    // Left Wheel
    canvas.drawCircle(const Offset(65, 78), 11, wheelTire);
    canvas.drawCircle(const Offset(65, 78), 11, wheelRim);
    canvas.drawCircle(const Offset(65, 78), 4.5, wheelHub);

    // Right Wheel
    canvas.drawCircle(const Offset(135, 78), 11, wheelTire);
    canvas.drawCircle(const Offset(135, 78), 11, wheelRim);
    canvas.drawCircle(const Offset(135, 78), 4.5, wheelHub);

    // Flag pole & Gold flag on roof
    final flagPole = Paint()
      ..color = const Color(0xFFE6C17A)
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(const Offset(48, 35), const Offset(48, 16), flagPole);

    final flagPath = Path()
      ..moveTo(48, 16)
      ..lineTo(70, 21.5)
      ..lineTo(48, 27)
      ..close();
    final flagPaint = Paint()..color = const Color(0xFFE6C17A);
    canvas.drawPath(flagPath, flagPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
