import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../core/api/auth_service.dart';
import '../../../../core/api/orders_service.dart';
import '../../../../core/models/event_model.dart';
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

class _TicketBookingPageState extends State<TicketBookingPage> {
  late EventSessionModel? _selectedSession;
  late TicketTypeModel? _selectedTicketType;
  int _quantity = 1;
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _promoController = TextEditingController();
  bool _termsAccepted = true;
  bool _isCheckingOut = false;

  @override
  void initState() {
    super.initState();
    // Pre-populate with logged in user info
    final user = AuthService().currentUser;
    if (user != null) {
      _nameController.text = user.fullName;
      _emailController.text = user.email;
      _phoneController.text = user.phone ?? '';
    }

    if (widget.initialBuyerName != null && widget.initialBuyerName!.isNotEmpty) {
      _nameController.text = widget.initialBuyerName!;
    }
    if (widget.initialBuyerEmail != null && widget.initialBuyerEmail!.isNotEmpty) {
      _emailController.text = widget.initialBuyerEmail!;
    }
    if (widget.initialBuyerPhone != null && widget.initialBuyerPhone!.isNotEmpty) {
      _phoneController.text = widget.initialBuyerPhone!;
    }
    if (widget.initialQuantity != null && widget.initialQuantity! > 0) {
      _quantity = widget.initialQuantity!;
    }

    // Match session
    if (widget.initialSessionId != null && widget.event.sessions.any((s) => s.id == widget.initialSessionId)) {
      _selectedSession = widget.event.sessions.firstWhere((s) => s.id == widget.initialSessionId);
    } else if (widget.event.sessions.isNotEmpty) {
      _selectedSession = widget.event.sessions.first;
    } else {
      _selectedSession = null;
    }

    // Default ticket type
    final availableTypes = _getAvailableTicketTypes();
    if (widget.initialTicketTypeId != null && availableTypes.any((t) => t.id == widget.initialTicketTypeId)) {
      _selectedTicketType = availableTypes.firstWhere((t) => t.id == widget.initialTicketTypeId);
    } else if (availableTypes.isNotEmpty) {
      _selectedTicketType = availableTypes.first;
    } else {
      _selectedTicketType = TicketTypeModel(
        id: 'tt-mock-1',
        name: 'Vé Tiêu Chuẩn (Standard)',
        price: widget.event.minPrice ?? 250000,
        availableQuantity: 50,
      );
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _promoController.dispose();
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
        id: 'tt-mock-vip',
        name: 'VIP Experience Pass',
        price: widget.event.maxPrice ?? 450000,
        description: 'Vị trí đắc địa gần sân khấu, lối đi ưu tiên Fast Pass',
        availableQuantity: 20,
      ),
      TicketTypeModel(
        id: 'tt-mock-ga',
        name: 'Standard Access Pass',
        price: widget.event.minPrice ?? 250000,
        description: 'Vé phổ thông tự do tham gia sự kiện',
        availableQuantity: 100,
      ),
    ];
  }

  Future<void> _handleCheckout() async {
    final name = _nameController.text.trim();
    final email = _emailController.text.trim();
    final phone = _phoneController.text.trim();

    if (name.isEmpty || email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng nhập Họ tên và Email người nhận vé!'), backgroundColor: AppColors.error),
      );
      return;
    }

    if (!_termsAccepted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng đồng ý với điều khoản đặt vé!'), backgroundColor: AppColors.error),
      );
      return;
    }

    setState(() => _isCheckingOut = true);

    final ticketTypeId = _selectedTicketType?.id ?? 'tt-1';
    final attendees = [
      OrderAttendeeInput(
        ticketTypeId: ticketTypeId,
        name: name,
        email: email,
      ),
    ];
    final items = [
      OrderItemInput(
        ticketTypeId: ticketTypeId,
        quantity: _quantity,
      ),
    ];

    final result = await OrdersService().checkoutOrder(
      eventId: widget.event.id,
      buyerName: name,
      buyerEmail: email,
      buyerPhone: phone.isNotEmpty ? phone : null,
      promoCode: _promoController.text.trim().isNotEmpty ? _promoController.text.trim() : null,
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

  @override
  Widget build(BuildContext context) {
    final ticketTypes = _getAvailableTicketTypes();
    final unitPrice = _selectedTicketType?.price ?? (widget.event.minPrice ?? 250000);
    final totalPrice = unitPrice * _quantity;
    final formattedTotal = NumberFormat.currency(locale: 'vi_VN', symbol: 'đ', decimalDigits: 0).format(totalPrice);

    return Scaffold(
      backgroundColor: const Color(0xFF070D1E),
      appBar: AppBar(
        backgroundColor: const Color(0xFF070D1E),
        elevation: 0,
        title: const Text('Đặt Vé Sự Kiện', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Event mini card
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFF101932),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withOpacity(0.08)),
              ),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: SizedBox(
                      width: 72,
                      height: 72,
                      child: widget.event.coverImageUrl != null
                          ? Image.network(widget.event.coverImageUrl!, fit: BoxFit.cover, errorBuilder: (_, __, ___) => Container(color: Colors.white10))
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
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          widget.event.formattedDateTime,
                          style: const TextStyle(color: Color(0xFFB0CADD), fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Session selector if multiple sessions
            if (widget.event.sessions.length > 1) ...[
              const Text('Chọn suất diễn:', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
              const SizedBox(height: 10),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: widget.event.sessions.map((s) {
                  final isSelected = _selectedSession?.id == s.id;
                  return ChoiceChip(
                    label: Text(s.name ?? s.formattedTime),
                    selected: isSelected,
                    selectedColor: AppColors.primaryContainer,
                    backgroundColor: const Color(0xFF101932),
                    labelStyle: TextStyle(
                      color: isSelected ? Colors.white : const Color(0xFFB0CADD),
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      fontSize: 13,
                    ),
                    onSelected: (val) {
                      if (val) {
                        setState(() {
                          _selectedSession = s;
                          final avail = _getAvailableTicketTypes();
                          if (avail.isNotEmpty) _selectedTicketType = avail.first;
                        });
                      }
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 24),
            ],

            // Ticket Types List
            const Text('Chọn hạng vé:', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
            const SizedBox(height: 12),
            ...ticketTypes.map((t) {
              final isSelected = _selectedTicketType?.id == t.id;
              final isSoldOut = t.isSoldOut;
              return GestureDetector(
                onTap: isSoldOut ? null : () => setState(() => _selectedTicketType = t),
                child: Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isSelected ? const Color(0xFF18284F) : const Color(0xFF101932),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isSelected ? AppColors.primaryContainer : Colors.white.withOpacity(0.08),
                      width: isSelected ? 1.5 : 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
                        color: isSelected ? AppColors.primaryContainer : Colors.white38,
                        size: 20,
                      ),
                      const SizedBox(width: 14),
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
                            if (t.description != null && t.description!.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(
                                t.description!,
                                style: const TextStyle(color: Color(0xFF8B9CB5), fontSize: 12),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        isSoldOut ? 'Hết vé' : t.formattedPrice,
                        style: TextStyle(
                          color: isSoldOut ? AppColors.error : const Color(0xFFFFB690),
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),

            const SizedBox(height: 20),

            // Quantity selector
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Số lượng vé:', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF101932),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white.withOpacity(0.1)),
                  ),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.remove, color: Colors.white, size: 18),
                        onPressed: _quantity > 1 ? () => setState(() => _quantity--) : null,
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Text(
                          '$_quantity',
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.add, color: Colors.white, size: 18),
                        onPressed: _quantity < 10 ? () => setState(() => _quantity++) : null,
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 28),

            // Attendee Info section
            const Text('Thông tin người nhận vé:', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
            const SizedBox(height: 12),

            _buildInputField('Họ và tên *', _nameController, Icons.person),
            const SizedBox(height: 12),
            _buildInputField('Email nhận vé *', _emailController, Icons.email, keyboardType: TextInputType.emailAddress),
            const SizedBox(height: 12),
            _buildInputField('Số điện thoại', _phoneController, Icons.phone, keyboardType: TextInputType.phone),

            const SizedBox(height: 24),

            // Promo code
            const Text('Mã giảm giá (nếu có):', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFF101932),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.white.withOpacity(0.1)),
                    ),
                    child: TextField(
                      controller: _promoController,
                      style: const TextStyle(color: Colors.white, fontSize: 14),
                      textCapitalization: TextCapitalization.characters,
                      decoration: const InputDecoration(
                        hintText: 'Nhập mã voucher / khuyến mãi',
                        hintStyle: TextStyle(color: Color(0xFF8B9CB5), fontSize: 13),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      ),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 20),

            // Terms checkbox
            Row(
              children: [
                Checkbox(
                  value: _termsAccepted,
                  activeColor: AppColors.primaryContainer,
                  onChanged: (val) => setState(() => _termsAccepted = val ?? false),
                ),
                const Expanded(
                  child: Text(
                    'Tôi đã đọc và đồng ý với các quy định, điều khoản sự kiện & chính sách hủy vé của ban tổ chức.',
                    style: TextStyle(color: Color(0xFFB0CADD), fontSize: 12),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // Total breakdown
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF101932),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Tổng thanh toán:', style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
                  Text(
                    formattedTotal,
                    style: const TextStyle(color: Color(0xFFFFB690), fontSize: 20, fontWeight: FontWeight.w800),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 28),

            // Submit button
            ElevatedButton(
              onPressed: _isCheckingOut ? null : _handleCheckout,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryContainer,
                minimumSize: const Size(double.infinity, 52),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                elevation: 6,
              ),
              child: _isCheckingOut
                  ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text(
                      'Tiến Hành Thanh Toán PayOS',
                      style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                    ),
            ),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildInputField(String label, TextEditingController controller, IconData icon, {TextInputType? keyboardType}) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF101932),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        style: const TextStyle(color: Colors.white, fontSize: 14),
        decoration: InputDecoration(
          prefixIcon: Icon(icon, color: const Color(0xFFB0CADD), size: 20),
          labelText: label,
          labelStyle: const TextStyle(color: Color(0xFF8B9CB5), fontSize: 13),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
      ),
    );
  }
}
