import 'package:flutter/material.dart';
import '../../../../core/api/tickets_service.dart';
import '../../../../core/models/event_model.dart';
import '../../../../core/theme/app_colors.dart';

class TicketBookingPage extends StatefulWidget {
  final EventModel event;

  const TicketBookingPage({super.key, required this.event});

  @override
  State<TicketBookingPage> createState() => _TicketBookingPageState();
}

class _TicketBookingPageState extends State<TicketBookingPage> {
  int _quantity = 1;
  String _selectedTicketType = 'VIP Phase 1';
  double _ticketPrice = 450000;
  final _promoController = TextEditingController();
  bool _isBooking = false;

  final List<Map<String, dynamic>> _ticketOptions = [
    {'name': 'VIP Phase 1', 'price': 450000.0, 'desc': 'Khu vực VIP gần sân khấu, tặng nước suối & Fast Pass lane'},
    {'name': 'Standard Access', 'price': 250000.0, 'desc': 'Vé phổ thông tự do trải nghiệm sự kiện'},
    {'name': 'Early Bird Ticket', 'price': 180000.0, 'desc': 'Số lượng giới hạn dành cho người đăng ký sớm'},
  ];

  Future<void> _handleConfirmBooking() async {
    setState(() => _isBooking = true);
    final result = await TicketsService().createOrder(
      eventId: widget.event.id,
      ticketTypeId: _selectedTicketType,
      quantity: _quantity,
      promotionCode: _promoController.text.trim(),
    );
    setState(() => _isBooking = false);

    if (mounted) {
      if (result['success']) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => AlertDialog(
            backgroundColor: const Color(0xFF0C1446),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: const Column(
              children: [
                Icon(Icons.check_circle, color: Color(0xFF22C55E), size: 60),
                SizedBox(height: 12),
                Text('Đặt Vé Thành Công!', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ],
            ),
            content: Text(
              'Đơn hàng cho ${widget.event.title} đã được thanh toán và xác nhận. Mã vé đã được thêm vào ví vé của bạn!',
              style: const TextStyle(color: AppColors.secondary, fontSize: 13),
              textAlign: TextAlign.center,
            ),
            actions: [
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(ctx); // Close dialog
                  Navigator.pop(context); // Return home/detail
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryContainer,
                  minimumSize: const Size(double.infinity, 44),
                ),
                child: const Text('Xem Vé Của Tôi', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result['message']), backgroundColor: AppColors.error),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final totalPrice = _ticketPrice * _quantity;

    return Scaffold(
      backgroundColor: const Color(0xFF081126),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Đặt Vé Sự Kiện', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Event summary card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF0C1446),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.secondary.withOpacity(0.15)),
              ),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.network(
                      widget.event.coverImageUrl ?? 'https://lh3.googleusercontent.com/aida-public/AB6AXuCsh1MyeOrExv0OTGWPXymZBnHdDiqnLogqJTML1O6osQPpeQP11Xa069TLuCwM-qYBI6xOmazp-7pg5MCxPM4TcaDHr7rhFP7PRyR7QS79TjINZdZ4k4DfgPm1umU1TYFb7w-_8bpoVl9R1VTWzNVop69NIQAPIhcnx8LZ1FDgsJ4ME58mNas6uSxXTAiSOwUKbbgiKBdEG1KIhXlEOKa-7pEzLNe1z7_DJbEJhZKSIizd6czYP7-3',
                      width: 70,
                      height: 70,
                      fit: BoxFit.cover,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(widget.event.title, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 4),
                        Text(widget.event.locationName ?? 'SECC Quận 7', style: const TextStyle(color: AppColors.secondary, fontSize: 12)),
                        Text(widget.event.startDate ?? 'Fri, Dec 28 • 18:00', style: const TextStyle(color: AppColors.primaryContainer, fontSize: 12, fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            const Text('CHỌN LOẠI VÉ', style: TextStyle(color: AppColors.secondary, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1)),
            const SizedBox(height: 12),

            ..._ticketOptions.map((opt) {
              final isSelected = _selectedTicketType == opt['name'];
              return GestureDetector(
                onTap: () {
                  setState(() {
                    _selectedTicketType = opt['name'];
                    _ticketPrice = opt['price'];
                  });
                },
                child: Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isSelected ? AppColors.primaryContainer.withOpacity(0.15) : const Color(0xFF0C1446),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isSelected ? AppColors.primaryContainer : AppColors.secondary.withOpacity(0.15),
                      width: isSelected ? 2 : 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
                        color: isSelected ? AppColors.primaryContainer : AppColors.secondary,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(opt['name'], style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                            const SizedBox(height: 2),
                            Text(opt['desc'], style: const TextStyle(color: AppColors.secondary, fontSize: 11)),
                          ],
                        ),
                      ),
                      Text(
                        '${(opt['price'] as double).toInt().toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]}.')} đ',
                        style: TextStyle(color: isSelected ? AppColors.primaryContainer : Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                    ],
                  ),
                ),
              );
            }),

            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Số lượng vé:', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF122155),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.secondary.withOpacity(0.2)),
                  ),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.remove, color: Colors.white, size: 20),
                        onPressed: _quantity > 1 ? () => setState(() => _quantity--) : null,
                      ),
                      Text('$_quantity', style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                      IconButton(
                        icon: const Icon(Icons.add, color: Colors.white, size: 20),
                        onPressed: _quantity < 10 ? () => setState(() => _quantity++) : null,
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),
            const Text('MÃ GIẢM GIÁ (PROMO)', style: TextStyle(color: AppColors.secondary, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1)),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Container(
                    height: 46,
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    decoration: BoxDecoration(
                      color: const Color(0xFF122155),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: TextField(
                      controller: _promoController,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                        hintText: 'Nhập mã VOUCHER...',
                        hintStyle: TextStyle(color: Colors.white38, fontSize: 13),
                        border: InputBorder.none,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Đã áp dụng mã giảm giá 10%!'), backgroundColor: Colors.green),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.surfaceContainerHigh,
                    minimumSize: const Size(80, 46),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: const Text('Áp Dụng', style: TextStyle(color: Colors.white)),
                ),
              ],
            ),

            const SizedBox(height: 32),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF0C1446),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Đơn giá:', style: TextStyle(color: AppColors.secondary, fontSize: 13)),
                      Text('${_ticketPrice.toInt().toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]}.')} đ x $_quantity', style: const TextStyle(color: Colors.white, fontSize: 13)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Phí hệ thống:', style: TextStyle(color: AppColors.secondary, fontSize: 13)),
                      Text('Miễn phí', style: TextStyle(color: Colors.greenAccent, fontSize: 13)),
                    ],
                  ),
                  const Divider(color: Colors.white12, height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Tổng thanh toán:', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                      Text(
                        '${totalPrice.toInt().toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]}.')} đ',
                        style: const TextStyle(color: AppColors.primaryContainer, fontWeight: FontWeight.bold, fontSize: 20),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: _isBooking ? null : _handleConfirmBooking,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryContainer,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  elevation: 8,
                ),
                child: _isBooking
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.payment, color: Colors.white),
                          SizedBox(width: 8),
                          Text('XÁC NHẬN ĐẶT VÉ', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                        ],
                      ),
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}
