import 'package:flutter/material.dart';
import '../../../../core/api/staff_service.dart';
import '../../../../core/models/ticket_model.dart';
import '../../../../core/theme/app_colors.dart';

class QrScannerPage extends StatefulWidget {
  const QrScannerPage({super.key});

  @override
  State<QrScannerPage> createState() => _QrScannerPageState();
}

class _QrScannerPageState extends State<QrScannerPage> {
  final _manualCodeController = TextEditingController();
  bool _isProcessing = false;
  Map<String, dynamic>? _lastScanResult;

  Future<void> _processTicketCode(String code) async {
    if (code.trim().isEmpty) return;
    setState(() {
      _isProcessing = true;
      _lastScanResult = null;
    });

    final res = await StaffService().checkInByQr(code.trim());

    setState(() {
      _isProcessing = false;
      _lastScanResult = res;
    });

    _manualCodeController.clear();
  }

  void _showManualInputDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF0C1446),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Nhập Mã Vé Thủ Công', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Nhập chuỗi mã vé (ví dụ: TICK-NEON-8842) để thực hiện check-in.', style: TextStyle(color: AppColors.secondary, fontSize: 13)),
            const SizedBox(height: 16),
            Container(
              height: 48,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: const Color(0xFF122155),
                borderRadius: BorderRadius.circular(10),
              ),
              child: TextField(
                controller: _manualCodeController,
                style: const TextStyle(color: Colors.white, fontFamily: 'monospace'),
                decoration: const InputDecoration(
                  hintText: 'TICK-XXXX-XXXX',
                  hintStyle: TextStyle(color: Colors.white38),
                  border: InputBorder.none,
                ),
              ),
            ),
          ],
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
              _processTicketCode(code);
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryContainer),
            child: const Text('Xác Thực Check-in', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final result = _lastScanResult;
    final isSuccess = result != null && result['success'] == true;

    return Scaffold(
      backgroundColor: const Color(0xFF081126),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0C1446),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Cổng Quét QR Check-In', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.flash_on, color: Colors.amber),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Đã bật đèn Flash hỗ trợ quét cổng!'), duration: Duration(seconds: 1)),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Simulated Scanner Viewfinder Container
          Expanded(
            child: Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  width: double.infinity,
                  color: Colors.black,
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.camera_alt_outlined, color: Colors.white.withOpacity(0.3), size: 80),
                        const SizedBox(height: 12),
                        Text(
                          'Đang kích hoạt máy quét camera...',
                          style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                ),
                // Camera Viewfinder Box Overlay
                Container(
                  width: 260,
                  height: 260,
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: isSuccess ? Colors.greenAccent : (result != null ? AppColors.error : AppColors.primaryContainer),
                      width: 3,
                    ),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: (isSuccess ? Colors.greenAccent : AppColors.primaryContainer).withOpacity(0.2),
                        blurRadius: 30,
                        spreadRadius: 5,
                      ),
                    ],
                  ),
                ),
                Positioned(
                  bottom: 30,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.7),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text(
                      'Căn chỉnh mã QR vào giữa khung hình',
                      style: TextStyle(color: Colors.white, fontSize: 12),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Feedback Result Panel
          if (_isProcessing)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              color: const Color(0xFF0C1446),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: AppColors.primaryContainer),
                  SizedBox(width: 14),
                  Text('Đang kiểm tra vé trên hệ thống...', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ],
              ),
            )
          else if (result != null)
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: isSuccess ? const Color(0xFF064E3B) : const Color(0xFF7F1D1D),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Icon(isSuccess ? Icons.check_circle : Icons.cancel, color: Colors.white, size: 36),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              isSuccess ? 'CHECK-IN THÀNH CÔNG!' : 'KHÔNG THỂ CHECK-IN!',
                              style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                            Text(result['message'] ?? '', style: const TextStyle(color: Colors.white70, fontSize: 13)),
                          ],
                        ),
                      ),
                    ],
                  ),
                  if (result['ticket'] != null) ...[
                    const Divider(color: Colors.white24, height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Khách hàng: ${(result['ticket'] as TicketModel).customerName}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                        Text('Loại vé: ${(result['ticket'] as TicketModel).ticketType}', style: const TextStyle(color: Colors.white70, fontSize: 12)),
                      ],
                    ),
                  ],
                ],
              ),
            ),

          // Bottom Action Controls
          Container(
            padding: const EdgeInsets.all(16),
            color: const Color(0xFF0C1446),
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _showManualInputDialog,
                    icon: const Icon(Icons.keyboard, color: Colors.white),
                    label: const Text('Nhập Mã Thủ Công', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.surfaceContainerHigh,
                      minimumSize: const Size(0, 48),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton(
                  onPressed: () => _processTicketCode('TICK-NEON-8842'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryContainer,
                    minimumSize: const Size(110, 48),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Quét Test', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
