import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../../../core/api/auth_service.dart';
import '../../../../core/api/staff_service.dart';
import '../../../../core/models/ticket_model.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_background.dart';
import '../../../auth/presentation/pages/login_page.dart';

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
  String? _lastScannedCode;

  // Active verified ticket state (displayed in-page card for seamless continuous scanning)
  String? _currentProcessingCode;
  String? _scannedRawQr;
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
      formats: const [BarcodeFormat.qrCode],
      torchEnabled: false,
      returnImage: false,
    );

    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);
  }

  Future<void> _relogin() async {
    await AuthService().logout();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginPage()),
      (route) => false,
    );
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
      final code = StaffService.normalizeRawQrInput(raw);
      if (code.isEmpty) continue;

      final now = DateTime.now();

      // Debounce identical QR code (whether currently displayed or failed verification)
      // so holding camera over the same ticket doesn't repeatedly spam verify requests.
      if (code == _lastScannedCode || code == _scannedRawQr || code == _currentProcessingCode) {
        if (_lastScannedTime != null && now.difference(_lastScannedTime!).inMilliseconds < 3500) {
          continue;
        }
      } else {
        // Immediate recognition for a different ticket with 600ms debounce
        if (_lastScannedTime != null && now.difference(_lastScannedTime!).inMilliseconds < 600) {
          continue;
        }
      }

      _lastScannedCode = code;
      _lastScannedTime = now;
      _processTicketCode(code);
      break;
    }
  }

  Future<void> _processTicketCode(String code) async {
    final cleanCode = code.trim();
    if (cleanCode.isEmpty || _isProcessing || _isCheckingIn) return;

    final parsed = StaffService.parseQrPayload(cleanCode);
    final effectiveCode = parsed['effective_code'] ?? cleanCode;

    setState(() {
      _isProcessing = true;
      _scannedRawQr = cleanCode;
      _currentProcessingCode = effectiveCode;
      _checkInError = null;
    });

    try {
      // 1. Chỉ lấy và xác thực thông tin vé trước, KHÔNG tự ý check-in ngay (giống Web StaffQrCheckInPage)
      final verifyRes = await StaffService().verifyQr(cleanCode);

      if (!mounted) return;

      final TicketModel? ticket =
          verifyRes['ticket'] is TicketModel ? (verifyRes['ticket'] as TicketModel) : null;

      if (verifyRes['success'] == true && ticket != null) {
        setState(() {
          _isProcessing = false;
          _activeVerifyResult = verifyRes;
          _activeTicket = ticket;
          _scannedRawQr = cleanCode;
          _currentProcessingCode = ticket.ticketCode;
          _justCheckedIn = false;
          _checkInError = null;
          _lastScanResult = {
            'success': true,
            'message': 'Đã tìm thấy vé ${ticket.ticketCode}',
          };
        });
      } else {
        final isExpired = verifyRes['requiresLogin'] == true;
        final rawMsg = verifyRes['raw_message']?.toString() ?? verifyRes['message']?.toString() ?? '';
        final friendlyMsg = isExpired
            ? (verifyRes['message']?.toString() ?? 'Phiên đăng nhập đã hết hạn. Vui lòng đăng nhập lại.')
            : StaffService.sanitizeStaffMessage(
                rawMsg,
                defaultMsg: 'Vé không tồn tại trong hệ thống hoặc mã QR không hợp lệ.',
              );
        debugPrint('[QrScannerPage] verifyQr failed (status=${verifyRes['statusCode']}, code=${verifyRes['errorCode']}): $friendlyMsg');

        setState(() {
          _isProcessing = false;
          _activeVerifyResult = null;
          _activeTicket = null;
          _currentProcessingCode = null;
          _scannedRawQr = null;
          _justCheckedIn = false;
          _checkInError = null;
          _lastScanResult = {
            'success': false,
            'message': friendlyMsg,
          };
        });

        // Nếu vé chưa đến giờ tham gia, hiển thị dialog thông báo nổi bật giống web Modal
        if (friendlyMsg == 'Vé này chưa đến giờ tham gia.' ||
            friendlyMsg.toLowerCase().contains('chưa đến giờ') ||
            rawMsg.toLowerCase().contains('chưa đến giờ')) {
          _showNotYetOpenDialog(friendlyMsg);
        } else {
          _showErrorSnackBar(friendlyMsg, isExpired: isExpired);
        }
      }
    } catch (e) {
      if (!mounted) return;
      final friendlyMsg = 'Lỗi kết nối khi kiểm tra vé: $e';
      setState(() {
        _isProcessing = false;
        _activeVerifyResult = null;
        _activeTicket = null;
        _currentProcessingCode = null;
        _scannedRawQr = null;
        _justCheckedIn = false;
        _checkInError = null;
        _lastScanResult = {
          'success': false,
          'message': friendlyMsg,
        };
      });

      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(friendlyMsg),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }
  }

  Future<void> _handleConfirmCheckIn() async {
    final ticket = _activeTicket;
    final rawQr = _scannedRawQr;
    final code = _currentProcessingCode ?? ticket?.ticketCode;
    if (ticket == null || _isCheckingIn) return;

    setState(() {
      _isCheckingIn = true;
      _checkInError = null;
    });

    try {
      final cleanGate = _selectedGate.split(' - ').first;

      // Matches Web StaffQrCheckInPage: checkInTicketByQr({ qrCode: scannedQrValue })
      // Only use manualCheckIn when no QR string was scanned. Never fall back to manual check-in on QR errors.
      final Map<String, dynamic> checkInRes;
      if (rawQr != null && rawQr.isNotEmpty) {
        checkInRes = await StaffService().checkInByQr(rawQr, gate: cleanGate);
      } else if (code != null && code.isNotEmpty) {
        checkInRes = await StaffService().checkInByQr(code, gate: cleanGate);
      } else {
        checkInRes = await StaffService().manualCheckIn(ticket.ticketId, gate: cleanGate);
      }

      if (!mounted) return;

      if (checkInRes['success'] == true) {
        final updated = checkInRes['ticket'] is TicketModel
            ? (checkInRes['ticket'] as TicketModel)
            : ticket.copyWith(
                status: 'USED',
                checkInStatus: 'CHECKED_IN',
                checkInTime: DateTime.now().toIso8601String(),
                checkinMethod: 'QR',
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
        final isExpired = checkInRes['requiresLogin'] == true;
        final rawMsg = checkInRes['raw_message'] ?? checkInRes['message'];
        final friendlyMsg = isExpired
            ? (checkInRes['message']?.toString() ?? 'Phiên đăng nhập đã hết hạn. Vui lòng đăng nhập lại.')
            : StaffService.sanitizeStaffMessage(
                rawMsg,
                defaultMsg: 'Check-in thất bại!',
              );
        debugPrint(
          '[QrScannerPage] checkInByQr failed (status=${checkInRes['statusCode']}, code=${checkInRes['errorCode']}): $friendlyMsg',
        );
        setState(() {
          _isCheckingIn = false;
          _checkInError = friendlyMsg;
          _lastScanResult = {
            'success': false,
            'message': friendlyMsg,
          };
        });
        if (isExpired) {
          _showErrorSnackBar(friendlyMsg, isExpired: true);
        }
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isCheckingIn = false;
        _checkInError = 'Lỗi hệ thống: $e';
      });
    }
  }

  void _showErrorSnackBar(String friendlyMsg, {required bool isExpired}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.cancel_rounded, color: Colors.white, size: 22),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                friendlyMsg,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white),
              ),
            ),
          ],
        ),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: Duration(seconds: isExpired ? 5 : 3),
        action: isExpired
            ? SnackBarAction(
                label: 'Đăng nhập lại',
                textColor: Colors.white,
                onPressed: _relogin,
              )
            : null,
      ),
    );
  }

  void _dismissActiveTicketCard() {
    setState(() {
      _activeVerifyResult = null;
      _activeTicket = null;
      _currentProcessingCode = null;
      _scannedRawQr = null;
      _lastScannedCode = null;
      _lastScannedTime = null;
      _isCheckingIn = false;
      _justCheckedIn = false;
      _checkInError = null;
    });
  }

  void _showNotYetOpenDialog(String message) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1708),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: Color(0xFFF59E0B), width: 1.5),
        ),
        title: const Row(
          children: [
            Icon(Icons.shield_outlined, color: Color(0xFFF59E0B), size: 28),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'Chưa Đến Giờ Check-in',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 17),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFF59E0B).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.4)),
              ),
              child: const Text(
                'CHƯA ĐẾN GIỜ CHECK-IN',
                style: TextStyle(
                  color: Color(0xFFF59E0B),
                  fontWeight: FontWeight.w800,
                  fontSize: 11,
                  letterSpacing: 0.8,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              message,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Vé hợp lệ nhưng cổng check-in của sự kiện hiện chưa mở.',
              style: TextStyle(color: Colors.white70, fontSize: 13),
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white12),
              ),
              child: const Row(
                children: [
                  Icon(Icons.access_time_filled, color: Color(0xFFF59E0B), size: 20),
                  SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Vui lòng thử lại sau',
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Chờ đến thời gian check-in do ban tổ chức thiết lập, sau đó quét lại mã vé này.',
                          style: TextStyle(color: Colors.white60, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFF59E0B),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text(
              'Đã hiểu',
              style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
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
                'Nhập chuỗi mã QR hoặc mã vé nếu camera không nhận diện được.',
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
                    style: const TextStyle(color: Colors.white, fontFamily: 'monospace', fontWeight: FontWeight.bold, fontSize: 14),
                    decoration: const InputDecoration(
                      hintText: 'EH-XXXXXXXX hoặc chuỗi QR',
                      hintStyle: TextStyle(color: Colors.white30, fontSize: 13),
                      border: InputBorder.none,
                      isDense: true,
                    ),
                  ),
                ),
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

  Widget _buildCompactItem({
    required IconData icon,
    required String label,
    required String value,
    String? subValue,
    bool highlight = false,
    bool isFullWidth = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 13, color: AppColors.secondary),
            const SizedBox(width: 4),
            Text(
              label,
              style: const TextStyle(color: AppColors.secondary, fontSize: 11),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          value,
          maxLines: isFullWidth ? 2 : 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: highlight ? AppColors.primaryContainer : Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 12.5,
            fontFamily: highlight ? 'monospace' : null,
          ),
        ),
        if (subValue != null && subValue.isNotEmpty)
          Text(
            subValue,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Colors.white60, fontSize: 10),
          ),
      ],
    );
  }


  Widget _buildStatusBadge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
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
          fontSize: 10.5,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.2,
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

    final maxHeight = MediaQuery.of(context).size.height * 0.88;

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
          physics: const ClampingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. Top Header Row: Status icon + Title/Subtitle + Close button
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: primaryColor.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                      border: Border.all(color: primaryColor, width: 1.5),
                    ),
                    child: Icon(
                      isAlreadyCheckedIn
                          ? (_justCheckedIn ? Icons.check_circle_rounded : Icons.verified_user_rounded)
                          : (canCheckIn
                              ? Icons.confirmation_number_outlined
                              : (isVerified ? Icons.warning_amber_rounded : Icons.cancel_rounded)),
                      color: primaryColor,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 10),
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
                          style: TextStyle(
                            color: primaryColor,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.2,
                          ),
                        ),
                        Text(
                          isAlreadyCheckedIn
                              ? (_justCheckedIn
                                  ? 'Đã vào cổng thành công'
                                  : 'Vé đã check-in trước đó')
                              : (canCheckIn
                                  ? 'Nhấn nút bên dưới để xác nhận vào cổng'
                                  : (verifyResult['message'] ?? (current != null ? current.formattedStatus : 'Vé không hợp lệ!'))),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: Colors.white70, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white70, size: 20),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    tooltip: 'Đóng',
                    onPressed: _dismissActiveTicketCard,
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // 2. Structured Information Grid: fits fully without scrolling
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFF0C1446).withValues(alpha: 0.85),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Row 1: Khách hàng & Mã vé
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: _buildCompactItem(
                            icon: Icons.person_outline,
                            label: 'Người tham dự',
                            value: current != null ? current.displayPrimaryName : 'Khách vãng lai',
                            subValue: current != null
                                ? (current.isDifferentAttendee
                                    ? (current.attendeeEmail ?? 'Chưa cung cấp email')
                                    : (current.buyerEmail ?? current.attendeeEmail))
                                : null,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _buildCompactItem(
                            icon: Icons.qr_code,
                            label: 'Mã vé',
                            value: current?.ticketCode ?? (code.contains('{') ? 'Mã vé' : code),
                            highlight: true,
                          ),
                        ),
                      ],
                    ),
                    const Divider(color: Colors.white10, height: 10),
                    // Row 2: Hạng vé & Vị trí ghế
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: _buildCompactItem(
                            icon: Icons.confirmation_number_outlined,
                            label: 'Hạng vé',
                            value: current?.ticketType ?? 'Tiêu chuẩn',
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _buildCompactItem(
                            icon: Icons.event_seat_outlined,
                            label: 'Vị trí ghế',
                            value: (current?.seatName != null && current!.seatName!.isNotEmpty)
                                ? current.seatName!
                                : 'Tự do (GA)',
                          ),
                        ),
                      ],
                    ),
                    const Divider(color: Colors.white10, height: 10),
                    // Row 3: Cổng soát & Trạng thái vé / Check-in time
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: _buildCompactItem(
                            icon: Icons.door_front_door_outlined,
                            label: 'Cổng soát vé',
                            value: _selectedGate,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    isAlreadyCheckedIn ? Icons.access_time : Icons.info_outline,
                                    size: 13,
                                    color: AppColors.secondary,
                                  ),
                                  const SizedBox(width: 4),
                                  const Text(
                                    'Trạng thái',
                                    style: TextStyle(color: AppColors.secondary, fontSize: 11),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 2),
                              Row(
                                children: [
                                  _buildStatusBadge(
                                    isAlreadyCheckedIn
                                        ? 'ĐÃ CHECK-IN'
                                        : (canCheckIn ? 'CHƯA CHECK-IN' : (current?.formattedStatus ?? 'KHÔNG HỢP LỆ')),
                                    primaryColor,
                                  ),
                                  if (isAlreadyCheckedIn && current.formattedCheckInTime.isNotEmpty) ...[
                                    const SizedBox(width: 4),
                                    Expanded(
                                      child: Text(
                                        current.formattedCheckInTime,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(color: primaryColor, fontSize: 10, fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    if (current != null && current.eventName.isNotEmpty) ...[
                      const Divider(color: Colors.white10, height: 10),
                      // Row 4: Sự kiện
                      _buildCompactItem(
                        icon: Icons.festival_outlined,
                        label: 'Sự kiện',
                        value: current.eventName,
                        isFullWidth: true,
                      ),
                    ],
                  ],
                ),
              ),

              if (_checkInError != null) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.error.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.error),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline, color: AppColors.error, size: 14),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          _checkInError!,
                          style: const TextStyle(color: Colors.white, fontSize: 11),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 10),

              // 3. Action Buttons
              if (canCheckIn && !isAlreadyCheckedIn) ...[
                Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: ElevatedButton.icon(
                        onPressed: _isCheckingIn ? null : _handleConfirmCheckIn,
                        icon: _isCheckingIn
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                              )
                            : const Icon(Icons.how_to_reg, color: Colors.white, size: 18),
                        label: Text(
                          _isCheckingIn ? 'ĐANG CHECK-IN...' : 'XÁC NHẬN CHECK-IN',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF22C55E),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 11),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          elevation: 3,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      onPressed: _dismissActiveTicketCard,
                      icon: const Icon(Icons.refresh, color: Colors.white70),
                      tooltip: 'Bỏ qua / Quét tiếp',
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.white12,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ],
                ),
              ] else ...[
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _dismissActiveTicketCard,
                    icon: const Icon(Icons.qr_code_scanner, color: Colors.white, size: 18),
                    label: const Text(
                      'QUÉT VÉ TIẾP THEO',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryContainer,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 11),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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

    return AppBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Stack(
        children: [
          // 1. Continuous Camera Viewfinder
          Positioned.fill(
            child: MobileScanner(
              controller: _scannerController,
              onDetect: _onDetect,
              errorBuilder: (context, error) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.videocam_off_rounded, color: AppColors.error, size: 48),
                        const SizedBox(height: 12),
                        Text(
                          'Không thể bật camera quét mã QR (${error.errorCode.name}).\nHãy cấp quyền Camera hoặc dùng nút Nhập Mã Thủ Công bên dưới.',
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.white70, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                );
              },
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
                      child: SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _showManualInputDialog,
                          icon: const Icon(Icons.keyboard, color: Colors.white, size: 18),
                          label: const Text(
                            'Nhập Mã Vé / QR Thủ Công',
                            softWrap: true,
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF0C1446).withValues(alpha: 0.92),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: BorderSide(color: Colors.white.withValues(alpha: 0.15)),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
          ),
        ],
      ),
    ),
  );
  }
}
