import 'package:flutter/material.dart';
import '../../../../core/api/feedbacks_service.dart';
import '../../../../core/theme/app_colors.dart';

class FeedbackPage extends StatefulWidget {
  final String? initialEventId;

  const FeedbackPage({super.key, this.initialEventId});

  @override
  State<FeedbackPage> createState() => _FeedbackPageState();
}

class _FeedbackPageState extends State<FeedbackPage> {
  List<EligibleFeedbackEventModel> _events = [];
  String? _selectedEventId;
  int _rating = 5;
  final _commentController = TextEditingController();
  bool _isLoading = true;
  bool _isSubmitting = false;

  final List<String> _ratingLabels = [
    '',
    'Rất thất vọng',
    'Chưa hài lòng',
    'Bình thường',
    'Rất tốt & Hài lòng',
    'Tuyệt vời đỉnh cao!',
  ];

  @override
  void initState() {
    super.initState();
    _loadEvents();
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _loadEvents() async {
    setState(() => _isLoading = true);
    final list = await FeedbacksService().getEligibleEvents();
    if (mounted) {
      setState(() {
        _events = list;
        if (widget.initialEventId != null && list.any((e) => e.id == widget.initialEventId)) {
          _selectedEventId = widget.initialEventId;
        } else if (list.isNotEmpty) {
          _selectedEventId = list.first.id;
        }
        _isLoading = false;
      });
    }
  }

  Future<void> _handleSubmit() async {
    if (_selectedEventId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng chọn sự kiện muốn đánh giá'), backgroundColor: AppColors.error),
      );
      return;
    }

    if (_commentController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng nhập nhận xét của bạn'), backgroundColor: AppColors.error),
      );
      return;
    }

    setState(() => _isSubmitting = true);
    final res = await FeedbacksService().submitFeedback(
      eventId: _selectedEventId!,
      rating: _rating,
      content: _commentController.text.trim(),
    );
    setState(() => _isSubmitting = false);

    if (mounted) {
      if (res['success'] == true) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: const Color(0xFF101932),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: const Column(
              children: [
                Icon(Icons.check_circle, color: Color(0xFF22C55E), size: 54),
                SizedBox(height: 12),
                Text('Đã Gửi Đánh Giá!', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ],
            ),
            content: const Text(
              'Cảm ơn bạn đã chia sẻ trải nghiệm để giúp ban tổ chức hoàn thiện hơn trong các sự kiện sắp tới!',
              style: TextStyle(color: Color(0xFFB0CADD), fontSize: 13),
              textAlign: TextAlign.center,
            ),
            actions: [
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  Navigator.pop(context);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryContainer,
                  minimumSize: const Size(double.infinity, 44),
                ),
                child: const Text('Hoàn tất', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(res['message'] ?? 'Lỗi gửi đánh giá'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF070D1E),
      appBar: AppBar(
        backgroundColor: const Color(0xFF070D1E),
        elevation: 0,
        title: const Text('Đánh Giá Sự Kiện', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primaryContainer))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title banner
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          AppColors.primaryContainer.withOpacity(0.2),
                          const Color(0xFF101932),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppColors.primaryContainer.withOpacity(0.3)),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.stars, color: Color(0xFFE6C17A), size: 36),
                        SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Phản hồi sự kiện',
                                style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                              ),
                              SizedBox(height: 4),
                              Text(
                                'Ý kiến của bạn là động lực to lớn giúp nâng tầm trải nghiệm lễ hội.',
                                style: TextStyle(color: Color(0xFFB0CADD), fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),
                  const Text('Chọn sự kiện bạn đã tham gia:', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                  const SizedBox(height: 10),

                  if (_events.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFF101932),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Text('Không có sự kiện nào đủ điều kiện đánh giá.', style: TextStyle(color: Color(0xFF8B9CB5))),
                    )
                  else
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                        color: const Color(0xFF101932),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.white.withOpacity(0.1)),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _selectedEventId,
                          isExpanded: true,
                          dropdownColor: const Color(0xFF101932),
                          icon: const Icon(Icons.keyboard_arrow_down, color: Colors.white70),
                          items: _events.map((e) {
                            return DropdownMenuItem<String>(
                              value: e.id,
                              child: Text(
                                e.title,
                                style: const TextStyle(color: Colors.white, fontSize: 14),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            );
                          }).toList(),
                          onChanged: (val) {
                            setState(() => _selectedEventId = val);
                          },
                        ),
                      ),
                    ),

                  const SizedBox(height: 28),
                  const Text('Mức độ hài lòng:', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                  const SizedBox(height: 14),

                  // 5 Stars
                  Center(
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: List.generate(5, (index) {
                            final star = index + 1;
                            return GestureDetector(
                              onTap: () => setState(() => _rating = star),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 6),
                                child: Icon(
                                  star <= _rating ? Icons.star_rounded : Icons.star_outline_rounded,
                                  color: const Color(0xFFE6C17A),
                                  size: 42,
                                ),
                              ),
                            );
                          }),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _ratingLabels[_rating],
                          style: const TextStyle(color: Color(0xFFE6C17A), fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 28),
                  const Text('Nhận xét chi tiết:', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                  const SizedBox(height: 10),

                  Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFF101932),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.white.withOpacity(0.1)),
                    ),
                    child: TextField(
                      controller: _commentController,
                      maxLines: 5,
                      style: const TextStyle(color: Colors.white, fontSize: 14),
                      decoration: const InputDecoration(
                        hintText: 'Âm thanh, ánh sáng, khâu soát vé hoặc trải nghiệm chung của bạn như thế nào?...',
                        hintStyle: TextStyle(color: Color(0xFF8B9CB5), fontSize: 13),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.all(16),
                      ),
                    ),
                  ),

                  const SizedBox(height: 32),
                  ElevatedButton(
                    onPressed: _isSubmitting ? null : _handleSubmit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryContainer,
                      minimumSize: const Size(double.infinity, 50),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      elevation: 4,
                    ),
                    child: _isSubmitting
                        ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Text('Gửi Đánh Giá', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),
    );
  }
}
