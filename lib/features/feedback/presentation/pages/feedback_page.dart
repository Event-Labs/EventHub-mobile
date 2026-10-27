import 'package:flutter/material.dart';
import '../../../../core/api/feedbacks_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_background.dart';

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

  final Map<int, Map<String, String>> _ratingSentiments = {
    1: {'label': 'Rất thất vọng', 'emoji': '😞', 'desc': 'Trải nghiệm không như mong đợi, khâu tổ chức còn nhiều hạn chế.'},
    2: {'label': 'Chưa hài lòng', 'emoji': '🙁', 'desc': 'Còn nhiều điểm cần ban tổ chức cải thiện và khắc phục.'},
    3: {'label': 'Bình thường', 'emoji': '😐', 'desc': 'Sự kiện ở mức ổn, đáp ứng được các nhu cầu cơ bản.'},
    4: {'label': 'Rất tốt & Hài lòng', 'emoji': '😊', 'desc': 'Sự kiện hấp dẫn, khâu tổ chức chu đáo và chuyên nghiệp!'},
    5: {'label': 'Tuyệt vời đỉnh cao!', 'emoji': '🤩', 'desc': 'Trải nghiệm xuất sắc từ âm thanh, ánh sáng đến khâu tiếp đón!'},
  };

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
        } else if (widget.initialEventId != null) {
          // If the event isn't in eligible list yet (e.g. mock), create temporary item
          _selectedEventId = widget.initialEventId;
          _events.insert(
            0,
            EligibleFeedbackEventModel(
              id: widget.initialEventId!,
              title: 'Sự kiện đã tham dự',
              date: 'Gần đây',
            ),
          );
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

    final comment = _commentController.text.trim();
    if (comment.length < 10) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Nội dung nhận xét cần có ít nhất 10 ký tự (Hiện tại: ${comment.length}/10)'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);
    final res = await FeedbacksService().submitFeedback(
      eventId: _selectedEventId!,
      rating: _rating,
      content: comment,
    );
    setState(() => _isSubmitting = false);

    if (mounted) {
      if (res['success'] == true) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => AlertDialog(
            backgroundColor: const Color(0xFF101932),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            title: const Column(
              children: [
                Icon(Icons.check_circle, color: Color(0xFF22C55E), size: 56),
                SizedBox(height: 12),
                Text(
                  'Đã Gửi Đánh Giá!',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
                ),
              ],
            ),
            content: const Text(
              'Cảm ơn bạn đã dành thời gian đóng góp ý kiến quý báu. Phản hồi của bạn đã được chuyển tới Ban tổ chức sự kiện!',
              style: TextStyle(color: Color(0xFFB0CADD), fontSize: 13, height: 1.4),
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
                  minimumSize: const Size(double.infinity, 46),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
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
    final sentiment = _ratingSentiments[_rating] ?? _ratingSentiments[5]!;
    final commentLength = _commentController.text.trim().length;

    return AppBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
        surfaceTintColor: Colors.transparent,
        title: const Text(
          'Đánh Giá Sự Kiện',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primaryContainer))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Event selector section
                  const Text(
                    'Sự kiện bạn đã tham dự:',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  const SizedBox(height: 10),

                  if (_events.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFF101932),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.white12),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.info_outline, color: Color(0xFFE6C17A), size: 20),
                          SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Bạn chỉ có thể đánh giá các sự kiện đã kết thúc mà bạn đã sở hữu vé hoặc đã check-in tham dự.',
                              style: TextStyle(color: Color(0xFFB0CADD), fontSize: 12, height: 1.3),
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF101932),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.white12),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _selectedEventId,
                          isExpanded: true,
                          dropdownColor: const Color(0xFF101932),
                          icon: const Icon(Icons.keyboard_arrow_down, color: Color(0xFFE6C17A)),
                          items: _events.map((evt) {
                            return DropdownMenuItem<String>(
                              value: evt.id,
                              child: Text(
                                evt.title,
                                style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            );
                          }).toList(),
                          onChanged: (val) => setState(() => _selectedEventId = val),
                        ),
                      ),
                    ),

                  const SizedBox(height: 28),

                  // Rating Section
                  Center(
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: const Color(0xFF101932),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.3),
                            blurRadius: 16,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          const Text(
                            'Trải nghiệm của bạn như thế nào?',
                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '${sentiment['emoji']} ${sentiment['label']}',
                            style: const TextStyle(color: Color(0xFFE6C17A), fontWeight: FontWeight.bold, fontSize: 15),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            sentiment['desc']!,
                            style: const TextStyle(color: Color(0xFF8B9CB5), fontSize: 12),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 16),

                          // 5 Stars row
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: List.generate(5, (index) {
                              final starNum = index + 1;
                              final isActive = starNum <= _rating;
                              return GestureDetector(
                                onTap: () => setState(() => _rating = starNum),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 6),
                                  child: Icon(
                                    isActive ? Icons.star_rounded : Icons.star_outline_rounded,
                                    color: isActive ? const Color(0xFFE6C17A) : Colors.white24,
                                    size: 40,
                                  ),
                                ),
                              );
                            }),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Comment Input Section
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Chi tiết nhận xét & đóng góp:',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                      Text(
                        '$commentLength / 2000 ký tự (tối thiểu 10)',
                        style: TextStyle(
                          color: commentLength >= 10 ? const Color(0xFF22C55E) : const Color(0xFFF59E0B),
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFF101932),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: commentLength >= 10 ? Colors.white12 : const Color(0xFFF59E0B).withValues(alpha: 0.4),
                      ),
                    ),
                    child: TextField(
                      controller: _commentController,
                      maxLines: 6,
                      maxLength: 2000,
                      onChanged: (_) => setState(() {}),
                      style: const TextStyle(color: Colors.white, fontSize: 13, height: 1.4),
                      decoration: const InputDecoration(
                        hintText: 'Hãy chia sẻ cảm nhận của bạn về sự kiện (âm thanh, ánh sáng, khâu soát vé check-in, công tác tổ chức, tiện ích...)...',
                        hintStyle: TextStyle(color: Color(0xFF8B9CB5), fontSize: 12),
                        border: InputBorder.none,
                        counterText: '',
                        contentPadding: EdgeInsets.all(16),
                      ),
                    ),
                  ),

                  const SizedBox(height: 30),

                  // Submit Button
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
                        : const Text(
                            'Gửi Đánh Giá Sự Kiện',
                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                          ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
      ),
    );
  }
}
