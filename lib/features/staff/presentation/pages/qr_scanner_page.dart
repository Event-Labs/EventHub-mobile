import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../../../core/api/auth_service.dart';
import '../../../../core/api/staff_service.dart';
import '../../../../core/models/ticket_model.dart';
import '../../../../core/theme/app_colors.dart';

class QrScannerPage extends StatefulWidget {
  final String? initialGate;
  final String? eventId;
  final String? eventTitle;

  const QrScannerPage({
    super.key,
    this.initialGate,
    this.eventId,
    this.eventTitle,
  });

  @override
  State<QrScannerPage> createState() => _QrScannerPageState();
}

class _QrScannerPageState extends State<QrScannerPage> with SingleTickerProviderStateMixin {
  late MobileScannerController _scannerController;
  late AnimationController _animController;
  final TextEditingController _manualCodeController = TextEditingController();

  late String _selectedGate;
  final List<String> _availableGates = [
    'GATE 01 - Main Entrance',
    'GATE 02 - VIP Lane',
    'GATE 03 - Fast Track',
    'GATE 04 - General Access',
    'GATE 05 - Staff & Media',
  ];

  bool _isProcessing = false;
  bool _isTorchOn = false;
  Map<String, dynamic>? _lastScanResult;
  DateTime? _lastScannedTime;

  // Active verified ticket state (displayed in-page card for seamless continuous scanning)
  String? _currentProcessingCode;
  Map<String, dynamic>? _activeVerifyResult;
  TicketModel? _activeTicket;
  bool _isCheckingIn = false;
  bool _justCheckedIn = false;
  String? _checkInError;

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
    _selectedGate = widget.initialGate ?? _availableGates[0];

    // DetectionSpeed.normal with 500ms timeout enables continuous barcode stream without caching lockup
    _scannerController = MobileScannerController(
      detectionSpeed: DetectionSpeed.normal,
      detectionTimeoutMs: 500,
      facing: CameraFacing.back,
      torchEnabled: false,
      returnImage: false,
    );

    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _animController.dispose();
    _manualCodeController.dispose();
    _scannerController.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_isProcessing || _isCheckingIn) return;

    final barcodes = capture.barcodes;
    for (final barcode in barcodes) {
      final raw = barcode.rawValue;
      if (raw == null) continue;
      final code = raw.trim();
      if (code.isEmpty) continue;

      final now = DateTime.now();

      // If camera is still pointed at the current ticket card:
      // Debounce for 3.5s so we do not re-verify the same ticket repeatedly
      if (code == _currentProcessingCode && _activeVerifyResult != null) {
        if (_lastScannedTime != null && now.difference(_lastScannedTime!).inMilliseconds < 3500) {
          continue;
        }
      } else {
        // If presenting a NEW/DIFFERENT ticket:
        // Immediate recognition with a crisp 600ms debounce
        if (_lastScannedTime != null && now.difference(_lastScannedTime!).inMilliseconds < 600) {
          continue;
        }
      }

      _lastScannedTime = now;
      _processTicketCode(code);
      break;
    }
  }

  Future<void> _processTicketCode(String code) async {
    final cleanCode = code.trim();
    if (cleanCode.isEmpty || _isProcessing || _isCheckingIn) return;

    setState(() {
      _isProcessing = true;
      _currentProcessingCode = cleanCode;
      _checkInError = null;
    });

    try {
      // 1. Chỉ lấy và xác thực thông tin vé trước, KHÔNG tự ý check-in ngay
      final verifyRes = await StaffService().verifyQr(cleanCode);

      if (!mounted) return;

      final TicketModel? ticket =
          verifyRes['ticket'] is TicketModel ? (verifyRes['ticket'] as TicketModel) : null;

      setState(() {
        _isProcessing = false;
        _activeVerifyResult = verifyRes;
        _activeTicket = ticket;
        _justCheckedIn = false;
        _checkInError = null;
        _lastScanResult = {
          'success': verifyRes['success'] == true,
          'message': verifyRes['message'] ?? (ticket != null ? 'Đã tìm thấy vé ${ticket.ticketCode}' : 'Không tìm thấy vé'),
        };
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isProcessing = false;
        _activeVerifyResult = {
          'success': false,
          'message': 'Lỗi kết nối khi xác thực vé: $e',
        };
        _activeTicket = null;
        _justCheckedIn = false;
        _checkInError = 'Lỗi kết nối: $e';
        _lastScanResult = {
          'success': false,
          'message': 'Lỗi khi kiểm tra vé: $e',
        };
      });
    }
  }

  Future<void> _handleConfirmCheckIn() async {
    final ticket = _activeTicket;
    final code = _currentProcessingCode;
    if (ticket == null || code == null || _isCheckingIn) return;

    setState(() {
      _isCheckingIn = true;
      _checkInError = null;
    });

    try {
      final cleanGate = _selectedGate.split(' - ').first;
      var checkInRes = await StaffService().checkInByQr(code, gate: cleanGate);
      if (checkInRes['success'] != true && ticket.ticketId.isNotEmpty) {
        checkInRes = await StaffService().manualCheckIn(ticket.ticketId, gate: cleanGate);
      }

      if (!mounted) return;

      if (checkInRes['success'] == true) {
        final updated = checkInRes['ticket'] is TicketModel
            ? (checkInRes['ticket'] as TicketModel)
            : ticket.copyWith(
                status: 'USED',
                checkInTime: DateTime.now().toIso8601String(),
              );

        setState(() {
          _isCheckingIn = false;
          _activeTicket = updated;
          _justCheckedIn = true;
          _checkInError = null;
          _lastScanResult = {
            'success': true,
            'message': 'Đã check-in vé: ${updated.ticketCode}',
          };
        });
      } else {
        setState(() {
          _isCheckingIn = false;
          _checkInError = checkInRes['message'] ?? 'Check-in thất bại!';
          _lastScanResult = {
            'success': false,
            'message': checkInRes['message'] ?? 'Check-in thất bại!',
          };
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isCheckingIn = false;
        _checkInError = 'Lỗi hệ thống: $e';
      });
    }
  }

  void _dismissActiveTicketCard() {
    setState(() {
      _activeVerifyResult = null;
      _activeTicket = null;
      _currentProcessingCode = null;
      _isCheckingIn = false;
      _justCheckedIn = false;
      _checkInError = null;
    });
  }

  void _showManualInputDialog() {
    _manualCodeController.clear();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF0C1446),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.keyboard, color: AppColors.primaryContainer, size: 22),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'Nhập Mã Vé Thủ Công',
                softWrap: true,
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 17),
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Nhập chuỗi mã vé hoặc mã đơn hàng nếu camera không nhận diện được.',
                style: TextStyle(color: AppColors.secondary, fontSize: 12),
              ),
              const SizedBox(height: 14),
              Container(
                height: 50,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  color: const Color(0xFF122155),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.secondary.withValues(alpha: 0.2)),
                ),
                child: Center(
                  child: TextField(
                    controller: _manualCodeController,
                    autofocus: true,
                    textCapitalization: TextCapitalization.characters,
                    style: const TextStyle(color: Colors.white, fontFamily: 'monospace', fontWeight: FontWeight.bold, fontSize: 15),
                    decoration: const InputDecoration(
                      hintText: 'TICK-XXXX-XXXX',
                      hintStyle: TextStyle(color: Colors.white30, fontSize: 13),
                      border: InputBorder.none,
                      isDense: true,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  _buildQuickChip('TICK-NEON-8842', 'Vé VIP 1'),
                  _buildQuickChip('TICK-BASS-4921', 'Vé GA 2'),
                ],
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Hủy', style: TextStyle(color: AppColors.secondary)),
          ),
          ElevatedButton(
            onPressed: () {
              final code = _manualCodeController.text.trim();
              Navigator.pop(ctx);
              if (code.isNotEmpty) {
                _processTicketCode(code);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryContainer,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Xác Thực Check-in', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickChip(String code, String label) {
    return ActionChip(
      backgroundColor: const Color(0xFF1E293B),
      label: Text(
        '$label ($code)',
        softWrap: true,
        style: const TextStyle(color: AppColors.secondary, fontSize: 11),
      ),
      onPressed: () {
        _manualCodeController.text = code;
      },
    );
  }

  void _showGateSelectorSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0C1446),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.door_sliding, color: AppColors.primaryContainer),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Chọn Cổng Check-In Hoạt Động',
                      softWrap: true,
                      style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              const Text(
                'Lịch sử check-in sẽ được ghi nhận tương ứng với cổng bạn chọn.',
                style: TextStyle(color: AppColors.secondary, fontSize: 12),
              ),
              const SizedBox(height: 14),
              ..._availableGates.map((gate) {
                final isSelected = _selectedGate == gate;
                return ListTile(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  tileColor: isSelected ? AppColors.primaryContainer.withValues(alpha: 0.15) : Colors.transparent,
                  leading: Icon(
                    isSelected ? Icons.check_circle : Icons.door_front_door_outlined,
                    color: isSelected ? AppColors.primaryContainer : AppColors.secondary,
                  ),
                  title: Text(
                    gate,
                    softWrap: true,
                    style: TextStyle(
                      color: isSelected ? Colors.white : Colors.white70,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      fontSize: 13,
                    ),
                  ),
                  trailing: isSelected
                      ? Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.primaryContainer,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Text('ĐANG CHỌN', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                        )
                      : null,
                  onTap: () {
                    setState(() => _selectedGate = gate);
                    Navigator.pop(ctx);
                  },
                );
              }),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(
    String label,
    String value, {
    IconData? icon,
    bool highlight = false,
    Color? valueColor,
    Widget? valueWidget,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (icon != null) ...[
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Icon(icon, size: 14, color: AppColors.secondary),
            ),
            const SizedBox(width: 6),
          ],
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
            child: Align(
              alignment: Alignment.centerRight,
              child: valueWidget ??
                  Text(
                    value,
                    textAlign: TextAlign.end,
                    softWrap: true,
                    style: TextStyle(
                      color: valueColor ?? (highlight ? AppColors.primaryContainer : Colors.white),
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                      fontFamily: highlight ? 'monospace' : null,
                    ),
                  ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.6)),
      ),
      child: Text(
        text,
        softWrap: true,
        textAlign: TextAlign.center,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.3,
        ),
      ),
    );
  }

  Widget _buildActiveTicketCard(BuildContext context) {
    final current = _activeTicket;
    final code = _currentProcessingCode ?? '';
    final verifyResult = _activeVerifyResult ?? {};
    final bool isVerified = verifyResult['success'] == true && current != null;
    final bool isAlreadyCheckedIn = current != null && (current.isUsed || _justCheckedIn);
    final bool canCheckIn = current != null && current.isValid && !isAlreadyCheckedIn;

    final Color primaryColor = isAlreadyCheckedIn
        ? (_justCheckedIn ? const Color(0xFF22C55E) : const Color(0xFF06B6D4))
        : (canCheckIn
            ? const Color(0xFF22C55E)
            : (isVerified ? const Color(0xFFF59E0B) : AppColors.error));

    final Color bgColor = isAlreadyCheckedIn
        ? (_justCheckedIn ? const Color(0xFF072118) : const Color(0xFF071F2C))
        : (canCheckIn
            ? const Color(0xFF072118)
            : const Color(0xFF260D12));

    final maxHeight = MediaQuery.of(context).size.height * 0.65;

    return Container(
      constraints: BoxConstraints(maxHeight: maxHeight),
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 10),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: primaryColor.withValues(alpha: 0.6),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: primaryColor.withValues(alpha: 0.25),
            blurRadius: 20,
            spreadRadius: 2,
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.6),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Top Drag Handle & Close Row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: primaryColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: primaryColor.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircleAvatar(radius: 3, backgroundColor: primaryColor),
                        const SizedBox(width: 5),
                        Text(
                          isAlreadyCheckedIn
                              ? (_justCheckedIn ? 'CHECK-IN XONG' : 'ĐÃ TỪNG CHECK-IN')
                              : (canCheckIn ? 'VÉ HỢP LỆ' : 'KHÔNG HỢP LỆ'),
                          style: TextStyle(color: primaryColor, fontSize: 10, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white70, size: 20),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    tooltip: 'Đóng thẻ quét',
                    onPressed: _dismissActiveTicketCard,
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Header Row: Status icon + Main Title + Subtitle
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: primaryColor.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                      border: Border.all(color: primaryColor, width: 2),
                    ),
                    child: Icon(
                      isAlreadyCheckedIn
                          ? (_justCheckedIn ? Icons.check_circle_rounded : Icons.verified_user_rounded)
                          : (canCheckIn
                              ? Icons.confirmation_number_outlined
                              : (isVerified ? Icons.warning_amber_rounded : Icons.cancel_rounded)),
                      color: primaryColor,
                      size: 26,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isAlreadyCheckedIn
                              ? (_justCheckedIn ? 'CHECK-IN THÀNH CÔNG!' : 'VÉ ĐÃ ĐƯỢC CHECK-IN!')
                              : (canCheckIn
                                  ? 'THÔNG TIN VÉ HỢP LỆ'
                                  : (isVerified ? 'VÉ KHÔNG THỂ CHECK-IN' : 'XÁC THỰC THẤT BẠI!')),
                          softWrap: true,
                          style: TextStyle(
                            color: primaryColor,
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.2,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          isAlreadyCheckedIn
                              ? (_justCheckedIn
                                  ? 'Đã ghi nhận vào cổng thành công. Đưa mã tiếp theo để quét tiếp.'
                                  : 'Vé này đã check-in trước đó, không thể soát lại.')
                              : (canCheckIn
                                  ? 'Bấm nút bên dưới để xác nhận check-in vào cổng.'
                                  : (verifyResult['message'] ?? (current != null ? current.formattedStatus : 'Vé không hợp lệ!'))),
                          softWrap: true,
                          style: const TextStyle(color: Colors.white70, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Details Table Box
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFF0C1446).withValues(alpha: 0.85),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                ),
                child: Column(
                  children: [
                    _buildDetailRow(
                      'Mã vé',
                      current?.ticketCode ?? code,
                      icon: Icons.qr_code,
                      highlight: true,
                    ),
                    const Divider(color: Colors.white12, height: 10),
                    _buildDetailRow(
                      'Trạng thái vé',
                      '',
                      icon: Icons.info_outline,
                      valueWidget: _buildStatusBadge(
                        isAlreadyCheckedIn
                            ? 'ĐÃ CHECK-IN'
                            : (canCheckIn ? 'CHƯA CHECK-IN' : (current?.formattedStatus ?? 'KHÔNG HỢP LỆ')),
                        primaryColor,
                      ),
                    ),
                    if (isAlreadyCheckedIn) ...[
                      const Divider(color: Colors.white12, height: 10),
                      _buildDetailRow(
                        'Thời gian check-in',
                        current.formattedCheckInTime.isNotEmpty
                            ? current.formattedCheckInTime
                            : 'Vừa xong',
                        icon: Icons.access_time,
                        valueColor: primaryColor,
                      ),
                    ],
                    const Divider(color: Colors.white12, height: 10),
                    _buildDetailRow(
                      'Cổng soát vé',
                      _selectedGate,
                      icon: Icons.door_front_door_outlined,
                    ),
                    if (current != null) ...[
                      const Divider(color: Colors.white12, height: 10),
                      _buildDetailRow(
                        'Khách hàng',
                        (current.customerName != null && current.customerName!.isNotEmpty)
                            ? current.customerName!
                            : 'Khách vãng lai',
                        icon: Icons.person_outline,
                      ),
                      if (current.customerEmail != null && current.customerEmail!.isNotEmpty) ...[
                        const Divider(color: Colors.white12, height: 10),
                        _buildDetailRow(
                          'Email',
                          current.customerEmail!,
                          icon: Icons.email_outlined,
                        ),
                      ],
                      const Divider(color: Colors.white12, height: 10),
                      _buildDetailRow(
                        'Hạng vé',
                        current.ticketType ?? 'Tiêu chuẩn',
                        icon: Icons.confirmation_number_outlined,
                      ),
                      if (current.seatName != null && current.seatName!.isNotEmpty) ...[
                        const Divider(color: Colors.white12, height: 10),
                        _buildDetailRow(
                          'Vị trí ghế',
                          current.seatName!,
                          icon: Icons.event_seat_outlined,
                        ),
                      ],
                      if (current.eventName.isNotEmpty) ...[
                        const Divider(color: Colors.white12, height: 10),
                        _buildDetailRow(
                          'Sự kiện',
                          current.eventName,
                          icon: Icons.festival_outlined,
                        ),
                      ],
                    ],
                  ],
                ),
              ),

              if (_checkInError != null) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.error.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.error),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Padding(
                        padding: EdgeInsets.only(top: 2),
                        child: Icon(Icons.error_outline, color: AppColors.error, size: 16),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _checkInError!,
                          softWrap: true,
                          style: const TextStyle(color: Colors.white, fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 14),

              // Action Buttons:
              // 1. If ticket is not checked in yet and valid -> Show button "XÁC NHẬN CHECK-IN"
              // 2. If ticket is ALREADY checked in -> DO NOT show button checkin, only show button "QUÉT VÉ TIẾP THEO"
              if (canCheckIn && !isAlreadyCheckedIn) ...[
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _isCheckingIn ? null : _handleConfirmCheckIn,
                    icon: _isCheckingIn
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                          )
                        : const Icon(Icons.how_to_reg, color: Colors.white, size: 20),
                    label: Text(
                      _isCheckingIn ? 'ĐANG XỬ LÝ CHECK-IN...' : 'XÁC NHẬN CHECK-IN (${_selectedGate.split(' - ').first})',
                      softWrap: true,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF22C55E),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 4,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Center(
                  child: TextButton(
                    onPressed: _dismissActiveTicketCard,
                    child: const Text(
                      'Bỏ qua / Quét vé khác',
                      softWrap: true,
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white60, fontSize: 12),
                    ),
                  ),
                ),
              ] else ...[
                // Vé đã được check-in hoặc không hợp lệ: Không hiển thị button check-in nữa, chỉ hiển thị thông tin và nút Quét tiếp
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _dismissActiveTicketCard,
                    icon: const Icon(Icons.qr_code_scanner, color: Colors.white, size: 18),
                    label: const Text(
                      'QUÉT VÉ TIẾP THEO',
                      softWrap: true,
                      textAlign: TextAlign.center,
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryContainer,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasActiveCard = _activeVerifyResult != null;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // 1. Continuous Camera Viewfinder
          Positioned.fill(
            child: MobileScanner(
              controller: _scannerController,
              onDetect: _onDetect,
            ),
          ),

          // 2. Animated Laser Line & Viewfinder Box
          Positioned.fill(
            child: Center(
              child: SizedBox(
                width: 250,
                height: 250,
                child: Stack(
                  children: [
                    // Corner Borders
                    Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: _isProcessing
                              ? AppColors.primaryContainer
                              : (hasActiveCard ? Colors.white30 : Colors.white.withValues(alpha: 0.5)),
                          width: 2,
                        ),
                      ),
                    ),
                    // Animated Scanning Laser Line
                    AnimatedBuilder(
                      animation: _animController,
                      builder: (context, child) {
                        return Positioned(
                          top: 250 * _animController.value,
                          left: 10,
                          right: 10,
                          child: Container(
                            height: 3,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Colors.transparent, AppColors.primaryContainer, Colors.transparent],
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.primaryContainer.withValues(alpha: 0.8),
                                  blurRadius: 10,
                                  spreadRadius: 2,
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                    // Hint in center
                    Align(
                      alignment: Alignment.bottomCenter,
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.65),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Text(
                            hasActiveCard ? 'Đưa mã vé tiếp theo để quét liên tục' : 'Đặt mã QR vé vào khung ngắm',
                            softWrap: true,
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: Colors.white, fontSize: 10),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // 3. Top Header & Controls Overlay
          SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // App Bar Row
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  child: Row(
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.black54,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: IconButton(
                          icon: const Icon(Icons.arrow_back, color: Colors.white, size: 20),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Cổng Soát Vé Camera',
                              softWrap: true,
                              style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
                            ),
                            if (widget.eventTitle != null)
                              Text(
                                widget.eventTitle!,
                                style: const TextStyle(color: AppColors.secondary, fontSize: 11),
                                softWrap: true,
                              ),
                          ],
                        ),
                      ),
                      // Flash Toggle
                      Container(
                        decoration: BoxDecoration(
                          color: _isTorchOn ? Colors.amber.withValues(alpha: 0.3) : Colors.black54,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: IconButton(
                          icon: Icon(
                            _isTorchOn ? Icons.flash_on : Icons.flash_off,
                            color: _isTorchOn ? Colors.amber : Colors.white,
                            size: 20,
                          ),
                          onPressed: () async {
                            await _scannerController.toggleTorch();
                            setState(() => _isTorchOn = !_isTorchOn);
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Switch Camera
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.black54,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: IconButton(
                          icon: const Icon(Icons.flip_camera_ios, color: Colors.white, size: 20),
                          onPressed: () => _scannerController.switchCamera(),
                        ),
                      ),
                    ],
                  ),
                ),

                // Gate Selector Bar
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
                  child: GestureDetector(
                    onTap: _showGateSelectorSheet,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0C1446).withValues(alpha: 0.85),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.primaryContainer.withValues(alpha: 0.4)),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.4),
                            blurRadius: 8,
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          const CircleAvatar(radius: 4, backgroundColor: Color(0xFF22C55E)),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _selectedGate,
                              style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                              softWrap: true,
                            ),
                          ),
                          const SizedBox(width: 6),
                          const Icon(Icons.swap_horiz, color: AppColors.primaryContainer, size: 16),
                          const SizedBox(width: 4),
                          const Text(
                            'ĐỔI CỔNG',
                            style: TextStyle(color: AppColors.primaryContainer, fontSize: 10, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                if (_lastScanResult != null && !hasActiveCard)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: (_lastScanResult!['success'] == true ? const Color(0xFF22C55E) : AppColors.error).withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: _lastScanResult!['success'] == true ? const Color(0xFF22C55E) : AppColors.error,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            _lastScanResult!['success'] == true ? Icons.check_circle : Icons.error_outline,
                            color: _lastScanResult!['success'] == true ? const Color(0xFF22C55E) : AppColors.error,
                            size: 14,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Kết quả: ${_lastScanResult!['message'] ?? ''}',
                              softWrap: true,
                              style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w500),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // 4. Processing overlay indicator
          if (_isProcessing)
            Container(
              color: Colors.black45,
              child: const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(color: AppColors.primaryContainer),
                    SizedBox(height: 14),
                    Text(
                      'Đang lấy thông tin vé...',
                      softWrap: true,
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ),

          // 5. Bottom Interactive Area
          Align(
            alignment: Alignment.bottomCenter,
            child: hasActiveCard
                ? _buildActiveTicketCard(context)
                : SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: _showManualInputDialog,
                              icon: const Icon(Icons.keyboard, color: Colors.white, size: 18),
                              label: const Text(
                                'Nhập Mã Thủ Công',
                                softWrap: true,
                                textAlign: TextAlign.center,
                                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF0C1446).withValues(alpha: 0.9),
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  side: BorderSide(color: Colors.white.withValues(alpha: 0.15)),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          ElevatedButton(
                            onPressed: () => _processTicketCode('TICK-NEON-8842'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primaryContainer,
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.bolt, color: Colors.white, size: 16),
                                SizedBox(width: 4),
                                Text(
                                  'Test Vé',
                                  softWrap: true,
                                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
