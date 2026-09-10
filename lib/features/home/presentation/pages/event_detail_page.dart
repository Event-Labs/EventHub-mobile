import 'package:flutter/material.dart';
import '../../../../core/api/events_service.dart';
import '../../../../core/models/event_model.dart';
import '../../../../core/theme/app_colors.dart';
import 'ticket_booking_page.dart';

class EventDetailPage extends StatefulWidget {
  final EventModel? event;
  final String? eventId;

  const EventDetailPage({super.key, this.event, this.eventId});

  @override
  State<EventDetailPage> createState() => _EventDetailPageState();
}

class _EventDetailPageState extends State<EventDetailPage> {
  EventModel? _event;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    if (widget.event != null) {
      _event = widget.event;
    } else if (widget.eventId != null) {
      _loadDetail();
    }
  }

  Future<void> _loadDetail() async {
    setState(() => _isLoading = true);
    final detail = await EventsService().getEventDetail(widget.eventId!);
    setState(() {
      _event = detail;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Color(0xFF081126),
        body: Center(child: CircularProgressIndicator(color: AppColors.primaryContainer)),
      );
    }

    final event = _event ??
        EventModel(
          id: 'evt-1',
          title: 'Neon Horizon Festival 2025',
          categoryName: 'MUSIC FESTIVAL',
          minPrice: 450000,
          startDate: 'Friday, Dec 28, 2025 • 18:00',
          locationName: 'SECC Exhibition Center, Quận 7',
          description: 'Trải nghiệm âm nhạc đa giác quan Neon Horizon 2025 với hệ thống âm thanh trình diễn đỉnh cao và sự góp mặt của hàng loạt nghệ sĩ tài năng.',
          coverImageUrl: 'https://lh3.googleusercontent.com/aida-public/AB6AXuCsh1MyeOrExv0OTGWPXymZBnHdDiqnLogqJTML1O6osQPpeQP11Xa069TLuCwM-qYBI6xOmazp-7pg5MCxPM4TcaDHr7rhFP7PRyR7QS79TjINZdZ4k4DfgPm1umU1TYFb7w-_8bpoVl9R1VTWzNVop69NIQAPIhcnx8LZ1FDgsJ4ME58mNas6uSxXTAiSOwUKbbgiKBdEG1KIhXlEOKa-7pEzLNe1z7_DJbEJhZKSIizd6czYP7-3',
        );

    return Scaffold(
      body: Stack(
        children: [
          SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeroImage(context, event),
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildEventTitle(event),
                      const SizedBox(height: 20),
                      _buildInfoRow(Icons.calendar_today, event.startDate ?? 'Friday, Dec 28, 2025', '18:00 - 02:00'),
                      const SizedBox(height: 16),
                      _buildInfoRow(Icons.location_on, event.locationName ?? 'SECC Exhibition Center', event.address ?? 'TP. Hồ Chí Minh'),
                      const SizedBox(height: 24),
                      _buildOrganizer(event),
                      const SizedBox(height: 24),
                      _buildDescription(event),
                      const SizedBox(height: 100),
                    ],
                  ),
                ),
              ],
            ),
          ),
          _buildAppBar(context),
          _buildBottomAction(context, event),
        ],
      ),
    );
  }

  Widget _buildAppBar(BuildContext context) {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                icon: const CircleAvatar(
                  backgroundColor: Colors.black45,
                  child: Icon(Icons.arrow_back, color: Colors.white),
                ),
                onPressed: () => Navigator.of(context).pop(),
              ),
              Row(
                children: [
                  IconButton(
                    icon: const CircleAvatar(
                      backgroundColor: Colors.black45,
                      child: Icon(Icons.share, color: Colors.white),
                    ),
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Đã chia sẻ liên kết sự kiện!')),
                      );
                    },
                  ),
                  IconButton(
                    icon: const CircleAvatar(
                      backgroundColor: Colors.black45,
                      child: Icon(Icons.bookmark_border, color: Colors.white),
                    ),
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Đã lưu sự kiện vào danh sách yêu thích!')),
                      );
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeroImage(BuildContext context, EventModel event) {
    return AspectRatio(
      aspectRatio: 4 / 3,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.network(
            event.coverImageUrl ?? 'https://lh3.googleusercontent.com/aida-public/AB6AXuCsh1MyeOrExv0OTGWPXymZBnHdDiqnLogqJTML1O6osQPpeQP11Xa069TLuCwM-qYBI6xOmazp-7pg5MCxPM4TcaDHr7rhFP7PRyR7QS79TjINZdZ4k4DfgPm1umU1TYFb7w-_8bpoVl9R1VTWzNVop69NIQAPIhcnx8LZ1FDgsJ4ME58mNas6uSxXTAiSOwUKbbgiKBdEG1KIhXlEOKa-7pEzLNe1z7_DJbEJhZKSIizd6czYP7-3',
            fit: BoxFit.cover,
          ),
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withOpacity(0.4),
                  Colors.transparent,
                  AppColors.background,
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEventTitle(EventModel event) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.primaryContainer.withOpacity(0.2),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                event.categoryName?.toUpperCase() ?? 'MUSIC FESTIVAL',
                style: const TextStyle(color: AppColors.primaryContainer, fontSize: 10, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.star, color: Colors.amber, size: 14),
            const Text(' 4.9 (1.2k đánh giá)', style: TextStyle(color: AppColors.secondary, fontSize: 12)),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          event.title,
          style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Colors.white),
        ),
      ],
    );
  }

  Widget _buildInfoRow(IconData icon, String title, String subtitle) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: AppColors.surfaceVariant.withOpacity(0.5),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: AppColors.primaryContainer, size: 22),
        ),
        const SizedBox(width: 16),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white)),
            Text(subtitle, style: const TextStyle(color: AppColors.secondary, fontSize: 12)),
          ],
        ),
      ],
    );
  }

  Widget _buildOrganizer(EventModel event) {
    return Row(
      children: [
        const CircleAvatar(
          radius: 20,
          backgroundColor: AppColors.primaryContainer,
          child: Icon(Icons.festival, color: Colors.white),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Ban Tổ Chức', style: TextStyle(color: AppColors.secondary, fontSize: 11)),
              Text(event.organizerName ?? 'EventHub Partner', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white)),
            ],
          ),
        ),
        TextButton(
          onPressed: () {},
          child: const Text('Theo dõi', style: TextStyle(color: AppColors.primaryContainer)),
        ),
      ],
    );
  }

  Widget _buildDescription(EventModel event) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Giới Thiệu Sự Kiện', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
        const SizedBox(height: 12),
        Text(
          event.description ?? 'Trải nghiệm sự kiện đỉnh cao tại EventHub với sân khấu hiện đại, dàn âm thanh chất lượng và nhiều phần trình diễn hấp dẫn.',
          style: const TextStyle(color: AppColors.secondary, fontSize: 14, height: 1.5),
        ),
      ],
    );
  }

  Widget _buildBottomAction(BuildContext context, EventModel event) {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.background.withOpacity(0.95),
          border: Border(top: BorderSide(color: Colors.white.withOpacity(0.05))),
        ),
        child: Row(
          children: [
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Giá vé từ', style: TextStyle(color: AppColors.secondary, fontSize: 12)),
                Text(event.formattedPrice, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.primaryContainer)),
              ],
            ),
            const SizedBox(width: 24),
            Expanded(
              child: ElevatedButton(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => TicketBookingPage(event: event)),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryContainer,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 50),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 8,
                ),
                child: const Text('ĐẶT VÉ NGAY', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
