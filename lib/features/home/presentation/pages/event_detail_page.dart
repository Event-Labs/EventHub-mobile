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
  bool _isFavoriteBusy = false;

  @override
  void initState() {
    super.initState();
    if (widget.event != null) {
      _event = widget.event;
    }
    _loadDetail();
  }

  Future<void> _loadDetail() async {
    final id = widget.eventId ?? widget.event?.id;
    if (id == null) return;

    if (_event == null) setState(() => _isLoading = true);
    final detail = await EventsService().getEventDetail(id);
    if (mounted) {
      setState(() {
        _event = detail;
        _isLoading = false;
      });
    }
  }

  Future<void> _handleToggleFavorite() async {
    if (_event == null) return;
    setState(() => _isFavoriteBusy = true);
    final res = await EventsService().toggleFavorite(_event!.id);
    if (mounted) {
      final isFav = res['isFavorited'] ?? !_event!.isFavorited;
      setState(() {
        _event = _event!.copyWith(isFavorited: isFav);
        _isFavoriteBusy = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(res['message'] ?? (isFav ? 'Đã thêm vào yêu thích' : 'Đã xóa khỏi yêu thích')),
          backgroundColor: Colors.black87,
          duration: const Duration(seconds: 1),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading && _event == null) {
      return const Scaffold(
        backgroundColor: Color(0xFF070D1E),
        body: Center(child: CircularProgressIndicator(color: AppColors.primaryContainer)),
      );
    }

    final event = _event;
    if (event == null) {
      return Scaffold(
        backgroundColor: const Color(0xFF070D1E),
        appBar: AppBar(backgroundColor: const Color(0xFF070D1E), elevation: 0),
        body: const Center(
          child: Text('Không tìm thấy sự kiện.', style: TextStyle(color: Colors.white70)),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF070D1E),
      body: Stack(
        children: [
          // Content
          SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeroImage(event),
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Title & Status
                      Text(
                        event.title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          height: 1.3,
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Time Tile
                      _buildInfoTile(
                        icon: Icons.calendar_today,
                        title: event.formattedDateTime,
                        subtitle: event.endTime != null ? 'Kết thúc: ${event.endTime}' : 'Thời gian diễn ra dự kiến',
                      ),
                      const SizedBox(height: 12),

                      // Venue Tile
                      _buildInfoTile(
                        icon: Icons.location_on,
                        title: event.venue?.name ?? 'Địa điểm sự kiện',
                        subtitle: event.locationSummary,
                      ),
                      const SizedBox(height: 20),

                      // Organizer Card
                      _buildOrganizerCard(event),
                      const SizedBox(height: 24),

                      // Ticket Types Section
                      _buildTicketTypesSection(event),
                      const SizedBox(height: 24),

                      // Description
                      const Text(
                        'Giới thiệu sự kiện',
                        style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        event.description != null && event.description!.isNotEmpty
                            ? event.description!
                            : 'Không có thông tin mô tả chi tiết.',
                        style: const TextStyle(
                          color: Color(0xFFDAE2FF),
                          fontSize: 14,
                          height: 1.5,
                        ),
                      ),

                      if (event.refundPolicy != null && event.refundPolicy!.isNotEmpty) ...[
                        const SizedBox(height: 24),
                        const Text(
                          'Chính sách hoàn vé',
                          style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: const Color(0xFF101932),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: Colors.white.withOpacity(0.08)),
                          ),
                          child: Text(
                            event.refundPolicy!,
                            style: const TextStyle(color: Color(0xFFB0CADD), fontSize: 13, height: 1.4),
                          ),
                        ),
                      ],

                      const SizedBox(height: 110), // Bottom bar padding
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Custom Top App Bar with back and favorite buttons
          _buildTopBar(event),

          // Sticky Bottom Action Bar
          _buildBottomBar(event),
        ],
      ),
    );
  }

  Widget _buildTopBar(EventModel event) {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: Container(
        padding: EdgeInsets.only(
          top: MediaQuery.of(context).padding.top + 8,
          left: 16,
          right: 16,
          bottom: 12,
        ),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.black.withOpacity(0.7),
              Colors.transparent,
            ],
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.55),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white24),
                ),
                child: const Icon(Icons.arrow_back, color: Colors.white, size: 20),
              ),
            ),
            GestureDetector(
              onTap: _isFavoriteBusy ? null : _handleToggleFavorite,
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.55),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: event.isFavorited ? const Color(0xFFC99A47) : Colors.white24,
                  ),
                  boxShadow: event.isFavorited
                      ? [BoxShadow(color: const Color(0xFFC99A47).withOpacity(0.5), blurRadius: 10)]
                      : null,
                ),
                child: Icon(
                  event.isFavorited ? Icons.favorite : Icons.favorite_border,
                  color: event.isFavorited ? const Color(0xFFE6C17A) : Colors.white,
                  size: 20,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeroImage(EventModel event) {
    return Stack(
      children: [
        SizedBox(
          height: 320,
          width: double.infinity,
          child: event.coverImageUrl != null
              ? Image.network(
                  event.coverImageUrl!,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(color: const Color(0xFF16254F)),
                )
              : Container(color: const Color(0xFF16254F)),
        ),
        Positioned.fill(
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.transparent,
                  const Color(0xFF070D1E).withOpacity(0.9),
                  const Color(0xFF070D1E),
                ],
                stops: const [0.3, 0.8, 1.0],
              ),
            ),
          ),
        ),
        Positioned(
          bottom: 16,
          left: 20,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.7),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFC99A47), width: 1),
            ),
            child: Text(
              event.categoryName?.toUpperCase() ?? 'SỰ KIỆN',
              style: const TextStyle(
                color: Color(0xFFE6C17A),
                fontWeight: FontWeight.bold,
                fontSize: 12,
                letterSpacing: 0.8,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInfoTile({required IconData icon, required String title, required String subtitle}) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF101932),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.primaryContainer.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: AppColors.primaryContainer, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(color: Color(0xFFB0CADD), fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrganizerCard(EventModel event) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF101932),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: AppColors.primaryContainer.withOpacity(0.3),
            backgroundImage: event.organizer?.avatarUrl != null ? NetworkImage(event.organizer!.avatarUrl!) : null,
            child: event.organizer?.avatarUrl == null ? const Icon(Icons.person, color: Colors.white, size: 22) : null,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Ban tổ chức', style: TextStyle(color: Color(0xFF8B9CB5), fontSize: 11)),
                const SizedBox(height: 2),
                Text(
                  event.organizerDisplayName,
                  style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
          const Icon(Icons.verified, color: Color(0xFF06B6D4), size: 18),
        ],
      ),
    );
  }

  Widget _buildTicketTypesSection(EventModel event) {
    if (event.ticketTypes.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Hạng vé & Giá vé',
          style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        ...event.ticketTypes.map((t) {
          return Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFF101932),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white.withOpacity(0.06)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(t.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                      if (t.description != null && t.description!.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(t.description!, style: const TextStyle(color: Color(0xFF8B9CB5), fontSize: 12)),
                      ],
                    ],
                  ),
                ),
                Text(
                  t.isSoldOut ? 'Hết vé' : t.formattedPrice,
                  style: TextStyle(
                    color: t.isSoldOut ? AppColors.error : const Color(0xFFFFB690),
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _buildBottomBar(EventModel event) {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Container(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 14,
          bottom: MediaQuery.of(context).padding.bottom + 14,
        ),
        decoration: BoxDecoration(
          color: const Color(0xFF0C142A).withOpacity(0.95),
          border: Border(top: BorderSide(color: Colors.white.withOpacity(0.08))),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.6), blurRadius: 20, offset: const Offset(0, -4)),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Giá vé từ', style: TextStyle(color: Color(0xFF8B9CB5), fontSize: 11)),
                  const SizedBox(height: 2),
                  Text(
                    event.formattedPrice,
                    style: const TextStyle(
                      color: Color(0xFFFFB690),
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => TicketBookingPage(event: event)),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryContainer,
                padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                elevation: 6,
              ),
              child: const Text(
                'Đặt Vé Ngay',
                style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
