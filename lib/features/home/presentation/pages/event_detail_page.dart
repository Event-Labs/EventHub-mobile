import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/api/auth_service.dart';
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
  bool _isOverviewExpanded = false;
  String? _selectedSessionId;
  final Set<String> _expandedSessionIds = {};

  @override
  void initState() {
    super.initState();
    if (widget.event != null) {
      _event = widget.event;
      _initFirstSession(widget.event!);
    }
    _loadDetail();
  }

  void _initFirstSession(EventModel event) {
    if (_selectedSessionId == null && event.sessions.isNotEmpty) {
      final now = DateTime.now();
      // Select first active session if available
      final activeSessions = event.sessions.where((s) {
        if (s.endTime != null) {
          final end = DateTime.tryParse(s.endTime!);
          return end != null && end.isAfter(now);
        }
        return true;
      }).toList();

      if (activeSessions.isNotEmpty) {
        _selectedSessionId = activeSessions.first.id;
        _expandedSessionIds.add(activeSessions.first.id);
      } else {
        _selectedSessionId = event.sessions.first.id;
        _expandedSessionIds.add(event.sessions.first.id);
      }
    }
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
        _initFirstSession(detail);
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

  DateTime? _parseToLocal(String? dateStr) {
    if (dateStr == null || dateStr.trim().isEmpty) return null;
    try {
      final parsed = DateTime.parse(dateStr);
      return parsed.toLocal();
    } catch (_) {
      return null;
    }
  }

  bool _isSessionExpired(EventSessionModel session) {
    final now = DateTime.now();
    if (session.endTime != null) {
      final end = _parseToLocal(session.endTime);
      if (end != null) return end.isBefore(now);
    }
    if (session.startTime != null) {
      final start = _parseToLocal(session.startTime);
      if (start != null) return start.isBefore(now.subtract(const Duration(hours: 4)));
    }
    return false;
  }

  bool _isEventExpired(EventModel event) {
    final now = DateTime.now();
    if (event.endTime != null) {
      final end = _parseToLocal(event.endTime);
      if (end != null) return end.isBefore(now);
    }
    if (event.startTime != null) {
      final start = _parseToLocal(event.startTime);
      if (start != null) return start.isBefore(now.subtract(const Duration(hours: 4)));
    }
    return false;
  }

  String _formatTime(String? dateStr) {
    final dt = _parseToLocal(dateStr);
    if (dt == null) return '';
    final hour = dt.hour.toString().padLeft(2, '0');
    final minute = dt.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  String _formatShortDate(String? dateStr) {
    final dt = _parseToLocal(dateStr);
    if (dt == null) return 'Chưa cập nhật ngày';

    const weekdays = [
      'Thứ 2',
      'Thứ 3',
      'Thứ 4',
      'Thứ 5',
      'Thứ 6',
      'Thứ 7',
      'Chủ nhật',
    ];
    final weekdayIndex = (dt.weekday >= 1 && dt.weekday <= 7) ? dt.weekday - 1 : 0;
    final weekday = weekdays[weekdayIndex];
    final day = dt.day.toString().padLeft(2, '0');
    final month = dt.month.toString();
    final year = dt.year.toString();
    return '$weekday, $day tháng $month, $year';
  }

  String _formatSessionTime(String? startStr, String? endStr) {
    final start = _formatTime(startStr);
    final end = _formatTime(endStr);

    if (start.isNotEmpty && end.isNotEmpty) return '$start - $end';
    if (start.isNotEmpty) return 'Từ $start';
    return 'Giờ diễn đang cập nhật';
  }

  String _formatHeroDateTime(String? startStr, String? endStr) {
    final dt = _parseToLocal(startStr);
    if (dt == null) return 'Sắp diễn ra';
    const weekdays = ['Thứ 2', 'Thứ 3', 'Thứ 4', 'Thứ 5', 'Thứ 6', 'Thứ 7', 'CN'];
    final weekday = weekdays[(dt.weekday >= 1 && dt.weekday <= 7) ? dt.weekday - 1 : 0];
    final day = dt.day.toString().padLeft(2, '0');
    final month = dt.month.toString().padLeft(2, '0');
    final year = dt.year;
    final timeStr = _formatSessionTime(startStr, endStr);
    return '$weekday, $day/$month/$year • $timeStr';
  }

  String _stripHtmlTags(String htmlString) {
    final RegExp exp = RegExp(r'<[^>]*>', multiLine: true, caseSensitive: false);
    return htmlString.replaceAll(exp, '').replaceAll('&nbsp;', ' ').replaceAll('&amp;', '&').trim();
  }

  Future<void> _openGoogleMaps(EventVenueModel venue) async {
    final lat = venue.latitude;
    final lng = venue.longitude;
    final query = venue.summary ?? venue.name ?? 'Địa điểm sự kiện';
    Uri uri;

    if (lat != null && lng != null) {
      uri = Uri.parse('https://www.google.com/maps/search/?api=1&query=$lat,$lng');
    } else {
      uri = Uri.parse('https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(query)}');
    }

    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (_) {}
  }

  void _proceedToBooking(EventModel event) {
    if (_isEventExpired(event)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Sự kiện đã kết thúc, không thể đặt vé.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    String? sessionId = _selectedSessionId;
    if (sessionId == null && event.sessions.isNotEmpty) {
      final validSession = event.sessions.firstWhere((s) => !_isSessionExpired(s), orElse: () => event.sessions.first);
      sessionId = validSession.id;
    }

    final user = AuthService().currentUser;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TicketBookingPage(
          event: event,
          initialSessionId: sessionId,
          initialBuyerName: user?.fullName,
          initialBuyerEmail: user?.email,
          initialBuyerPhone: user?.phone,
        ),
      ),
    );
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

    final isExpired = _isEventExpired(event);
    final selectedSession = event.sessions.firstWhere(
      (s) => s.id == _selectedSessionId,
      orElse: () => event.sessions.isNotEmpty ? event.sessions.first : EventSessionModel(id: ''),
    );

    return Scaffold(
      backgroundColor: const Color(0xFF070D1E),
      body: Stack(
        children: [
          // Scrollable Content
          SingleChildScrollView(
            padding: const EdgeInsets.only(bottom: 110),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. Hero Header (Banner with bottom gradient mask & metadata)
                _buildHeroHeader(event),

                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 16),

                      // 2. Bento Card: Lịch Diễn & Các Suất Diễn (Core booking section)
                      _buildSessionsSection(event),
                      const SizedBox(height: 20),

                      // 3. Bento Card: Tổng Quan Sự Kiện
                      _buildOverviewSection(event),
                      const SizedBox(height: 20),

                      // 4. Bento Card: Địa Điểm Tổ Chức
                      _buildVenueSection(event),
                      const SizedBox(height: 20),

                      // 5. Bento Card: Ban Tổ Chức
                      _buildOrganizerCard(event),
                      const SizedBox(height: 20),

                      const SizedBox(height: 10),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Top Floating Navigation Bar
          _buildFloatingTopBar(event),

          // Bottom Fixed Action Bar (with selected session info and Book button)
          _buildBottomActionBar(event, selectedSession, isExpired),
        ],
      ),
    );
  }

  // ==========================================
  // 1. HERO HEADER COMPONENT
  // ==========================================
  Widget _buildHeroHeader(EventModel event) {
    final heroImage = event.bannerUrl ?? event.coverImageUrl;

    return Stack(
      children: [
        // Image
        SizedBox(
          height: 380,
          width: double.infinity,
          child: heroImage != null && heroImage.isNotEmpty
              ? Image.network(
                  heroImage,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(color: const Color(0xFF16254F)),
                )
              : Container(color: const Color(0xFF16254F)),
        ),

        // Gradient fading bottom mask (smooth blend into dark background)
        Positioned.fill(
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.transparent,
                  const Color(0xFF070D1E).withOpacity(0.4),
                  const Color(0xFF070D1E).withOpacity(0.85),
                  const Color(0xFF070D1E),
                ],
                stops: const [0.0, 0.5, 0.8, 1.0],
              ),
            ),
          ),
        ),

        // Glow effect
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          height: 120,
          child: Container(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: const Alignment(0, 1),
                radius: 1.2,
                colors: [
                  AppColors.primaryContainer.withOpacity(0.18),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ),

        // Text & Category Overlay
        Positioned(
          bottom: 12,
          left: 16,
          right: 16,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Category Chip
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.7),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFC99A47).withOpacity(0.8), width: 1.2),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFC99A47).withOpacity(0.3),
                      blurRadius: 10,
                      spreadRadius: 1,
                    ),
                  ],
                ),
                child: Text(
                  event.categoryName?.toUpperCase() ?? 'SỰ KIỆN',
                  style: const TextStyle(
                    color: Color(0xFFE6C17A),
                    fontWeight: FontWeight.w800,
                    fontSize: 11,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
              const SizedBox(height: 10),

              // Title
              Text(
                event.title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.5,
                  height: 1.25,
                  shadows: [
                    Shadow(color: Colors.black, blurRadius: 12, offset: Offset(0, 2)),
                  ],
                ),
              ),

              // Short Description (if any)
              if (event.shortDescription != null && event.shortDescription!.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  event.shortDescription!,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.88),
                    fontSize: 13,
                    height: 1.35,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              const SizedBox(height: 12),

              // Quick Info Row
              Wrap(
                spacing: 14,
                runSpacing: 6,
                children: [
                  _buildQuickInfo(Icons.verified_user_outlined, event.organizerDisplayName),
                  _buildQuickInfo(Icons.calendar_today_outlined, _formatHeroDateTime(event.startTime, event.endTime)),
                  _buildQuickInfo(Icons.location_on_outlined, event.locationSummary),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildQuickInfo(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: const Color(0xFF06B6D4), size: 14),
        const SizedBox(width: 5),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 220),
          child: Text(
            text,
            style: const TextStyle(color: Color(0xFFDAE2FF), fontSize: 12),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  // ==========================================
  // 2. BENTO CARD: LỊCH DIỄN & SUẤT DIỄN
  // ==========================================
  Widget _buildSessionsSection(EventModel event) {
    final sessions = event.sessions;

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF101932),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF06B6D4).withOpacity(0.2)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF06B6D4).withOpacity(0.06),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.03),
              border: Border(bottom: BorderSide(color: Colors.white.withOpacity(0.06))),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      width: 4,
                      height: 16,
                      decoration: BoxDecoration(
                        color: const Color(0xFF06B6D4),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'Lịch diễn & Hạng vé',
                      style: TextStyle(
                        color: Color(0xFF06B6D4),
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        letterSpacing: -0.2,
                      ),
                    ),
                  ],
                ),
                Text(
                  '${sessions.length} suất diễn',
                  style: const TextStyle(color: Color(0xFF8B9CB5), fontSize: 12),
                ),
              ],
            ),
          ),

          // Sessions List
          Padding(
            padding: const EdgeInsets.all(14),
            child: sessions.isEmpty
                ? const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: Center(
                      child: Text('Lịch diễn đang được cập nhật.', style: TextStyle(color: Color(0xFF8B9CB5), fontSize: 13)),
                    ),
                  )
                : Column(
                    children: sessions.map((session) {
                      final isSelected = _selectedSessionId == session.id;
                      final isExpanded = _expandedSessionIds.contains(session.id);
                      final isExpired = _isSessionExpired(session);
                      final tickets = session.ticketTypes.isNotEmpty ? session.ticketTypes : event.ticketTypes;

                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: isSelected ? const Color(0xFF06B6D4).withOpacity(0.08) : const Color(0xFF0A1024),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isSelected
                                ? const Color(0xFFC99A47)
                                : Colors.white.withOpacity(0.08),
                            width: isSelected ? 1.8 : 1,
                          ),
                          boxShadow: isSelected
                              ? [
                                  BoxShadow(
                                    color: const Color(0xFFC99A47).withOpacity(0.25),
                                    blurRadius: 12,
                                  ),
                                ]
                              : null,
                        ),
                        child: Column(
                          children: [
                            // Session Header Row
                            Padding(
                              padding: const EdgeInsets.all(12),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Expand Toggle Button
                                  GestureDetector(
                                    onTap: () {
                                      setState(() {
                                        if (isExpanded) {
                                          _expandedSessionIds.remove(session.id);
                                        } else {
                                          _expandedSessionIds.add(session.id);
                                        }
                                      });
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.all(6),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withOpacity(0.05),
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(
                                        isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                                        color: Colors.white70,
                                        size: 20,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 10),

                                  // Session Details (Exact match to web design)
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        // Line 1: Time range (e.g. 09:21 - 10:21)
                                        Text(
                                          _formatSessionTime(session.startTime, session.endTime),
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 14,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        const SizedBox(height: 3),

                                        // Line 2: Date with Vietnamese weekday (e.g. Thứ 7, 24 tháng 10, 2026)
                                        Text(
                                          _formatShortDate(session.startTime),
                                          style: const TextStyle(
                                            color: Color(0xFF06B6D4),
                                            fontSize: 14,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),

                                  // Select Button (allows selecting and unselecting)
                                  ElevatedButton(
                                    onPressed: isExpired
                                        ? null
                                        : () {
                                            setState(() {
                                              if (_selectedSessionId == session.id) {
                                                _selectedSessionId = null;
                                              } else {
                                                _selectedSessionId = session.id;
                                                _expandedSessionIds.add(session.id);
                                              }
                                            });
                                          },
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: isSelected
                                          ? const Color(0xFFE6C17A)
                                          : Colors.white.withOpacity(0.1),
                                      foregroundColor: isSelected ? const Color(0xFF070D1E) : Colors.white,
                                      disabledBackgroundColor: const Color(0xFF1E2846),
                                      disabledForegroundColor: Colors.white38,
                                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                                      elevation: isSelected ? 4 : 0,
                                    ),
                                    child: Text(
                                      isExpired
                                          ? 'Hết hạn'
                                          : (isSelected ? '✓ Đã chọn' : 'Chọn'),
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            // Expanded Ticket Classes
                            if (isExpanded) ...[
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                decoration: BoxDecoration(
                                  color: Colors.black.withOpacity(0.2),
                                  border: Border(top: BorderSide(color: Colors.white.withOpacity(0.06))),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'CÁC HẠNG VÉ',
                                      style: TextStyle(
                                        color: Color(0xFFE6C17A),
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    if (tickets.isEmpty)
                                      const Text('Chưa có thông tin vé cho suất này.', style: TextStyle(color: Colors.white38, fontSize: 12))
                                    else
                                      ...tickets.map((ticket) {
                                        final isSoldOut = ticket.isSoldOut;
                                        return Container(
                                          margin: const EdgeInsets.only(bottom: 8),
                                          padding: const EdgeInsets.all(10),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFF101932),
                                            borderRadius: BorderRadius.circular(12),
                                            border: Border.all(color: Colors.white.withOpacity(0.06)),
                                          ),
                                          child: Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            children: [
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      ticket.name,
                                                      style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                                                    ),
                                                    if (ticket.description != null && ticket.description!.isNotEmpty) ...[
                                                      const SizedBox(height: 2),
                                                      Text(
                                                        ticket.description!,
                                                        style: const TextStyle(color: Color(0xFF8B9CB5), fontSize: 11),
                                                        maxLines: 1,
                                                        overflow: TextOverflow.ellipsis,
                                                      ),
                                                    ],
                                                    const SizedBox(height: 3),
                                                    Text(
                                                      isSoldOut ? 'Hết vé' : 'Còn ${ticket.availableQuantity} vé',
                                                      style: TextStyle(
                                                        color: isSoldOut ? AppColors.error : const Color(0xFF06B6D4),
                                                        fontSize: 11,
                                                        fontWeight: FontWeight.w600,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              Text(
                                                ticket.formattedPrice,
                                                style: const TextStyle(
                                                  color: Color(0xFFE6C17A),
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ],
                                          ),
                                        );
                                      }),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                      );
                    }).toList(),
                  ),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // 3. BENTO CARD: TỔNG QUAN (OVERVIEW)
  // ==========================================
  Widget _buildOverviewSection(EventModel event) {
    final rawDescription = event.description ?? event.shortDescription ?? 'Thông tin chi tiết đang được cập nhật.';
    final cleanDescription = _stripHtmlTags(rawDescription);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF101932),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.25), blurRadius: 16, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.notes, color: Color(0xFFE6C17A), size: 20),
              SizedBox(width: 8),
              Text(
                'Tổng quan sự kiện',
                style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            cleanDescription,
            style: const TextStyle(
              color: Color(0xFFDAE2FF),
              fontSize: 14,
              height: 1.55,
            ),
            maxLines: _isOverviewExpanded ? null : 4,
            overflow: _isOverviewExpanded ? TextOverflow.visible : TextOverflow.ellipsis,
          ),
          if (cleanDescription.length > 180) ...[
            const SizedBox(height: 8),
            GestureDetector(
              onTap: () => setState(() => _isOverviewExpanded = !_isOverviewExpanded),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    _isOverviewExpanded ? 'Thu gọn' : 'Xem thêm chi tiết',
                    style: const TextStyle(
                      color: Color(0xFF06B6D4),
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    _isOverviewExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                    color: const Color(0xFF06B6D4),
                    size: 18,
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ==========================================
  // 4. BENTO CARD: ĐỊA ĐIỂM TỔ CHỨC
  // ==========================================
  Widget _buildVenueSection(EventModel event) {
    final venue = event.venue;
    final venueName = venue?.name ?? 'Địa điểm sự kiện';
    final address = event.locationSummary;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF101932),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.location_on_outlined, color: Color(0xFF06B6D4), size: 20),
              SizedBox(width: 8),
              Text(
                'Địa điểm tổ chức',
                style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            venueName,
            style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            address,
            style: const TextStyle(color: Color(0xFFB0CADD), fontSize: 13, height: 1.4),
          ),
          const SizedBox(height: 14),

          // Google Maps Action Button
          OutlinedButton.icon(
            onPressed: venue != null ? () => _openGoogleMaps(venue) : null,
            icon: const Icon(Icons.map_outlined, size: 18, color: Color(0xFF06B6D4)),
            label: const Text('Mở chỉ đường Google Maps', style: TextStyle(color: Color(0xFF06B6D4), fontWeight: FontWeight.w600, fontSize: 13)),
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: const Color(0xFF06B6D4).withOpacity(0.4)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // 5. BENTO CARD: BAN TỔ CHỨC
  // ==========================================
  Widget _buildOrganizerCard(EventModel event) {
    final org = event.organizer;
    final name = event.organizerDisplayName;
    final avatar = org?.avatarUrl;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF101932),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF1E2846),
              border: Border.all(color: const Color(0xFFE6C17A).withOpacity(0.5), width: 1.5),
            ),
            clipBehavior: Clip.antiAlias,
            child: avatar != null && avatar.isNotEmpty
                ? Image.network(
                    avatar,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => _buildOrganizerInitials(name),
                  )
                : _buildOrganizerInitials(name),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Ban tổ chức', style: TextStyle(color: Color(0xFF8B9CB5), fontSize: 11)),
                const SizedBox(height: 2),
                Text(
                  name,
                  style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const Icon(Icons.verified, color: Color(0xFF06B6D4), size: 20),
        ],
      ),
    );
  }

  Widget _buildOrganizerInitials(String name) {
    final initial = name.isNotEmpty ? name.trim().characters.first.toUpperCase() : 'B';
    return Center(
      child: Text(
        initial,
        style: const TextStyle(color: Color(0xFFE6C17A), fontWeight: FontWeight.bold, fontSize: 18),
      ),
    );
  }


  // ==========================================
  // FLOATING TOP BAR
  // ==========================================
  Widget _buildFloatingTopBar(EventModel event) {
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
              Colors.black.withOpacity(0.75),
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
                  color: Colors.black.withOpacity(0.6),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white.withOpacity(0.15)),
                ),
                child: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 18),
              ),
            ),
            GestureDetector(
              onTap: _isFavoriteBusy ? null : _handleToggleFavorite,
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.6),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: event.isFavorited ? const Color(0xFFC99A47) : Colors.white.withOpacity(0.15),
                    width: event.isFavorited ? 1.5 : 1,
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

  // ==========================================
  // 7. FIXED BOTTOM ACTION BAR
  // ==========================================
  Widget _buildBottomActionBar(EventModel event, EventSessionModel selectedSession, bool isExpired) {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Container(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 12,
          bottom: MediaQuery.of(context).padding.bottom + 12,
        ),
        decoration: BoxDecoration(
          color: const Color(0xFF0C142A).withOpacity(0.96),
          border: Border(top: BorderSide(color: Colors.white.withOpacity(0.08))),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.7), blurRadius: 24, offset: const Offset(0, -6)),
          ],
        ),
        child: Row(
          children: [
            // Selected Session & Price Information
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _selectedSessionId != null && selectedSession.startTime != null
                        ? 'Suất: ${_formatSessionTime(selectedSession.startTime, selectedSession.endTime)}'
                        : 'Giá vé từ',
                    style: const TextStyle(color: Color(0xFF8B9CB5), fontSize: 11),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    event.formattedPrice,
                    style: const TextStyle(
                      color: Color(0xFFE6C17A),
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),

            // Book Button (Luxury gold gradient)
            ElevatedButton(
              onPressed: isExpired ? null : () => _proceedToBooking(event),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFE6C17A),
                disabledBackgroundColor: const Color(0xFF1E2846),
                padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                elevation: isExpired ? 0 : 8,
                shadowColor: const Color(0xFFC99A47).withOpacity(0.5),
              ),
              child: Text(
                isExpired ? 'Đã kết thúc' : 'Đặt Vé Ngay',
                style: TextStyle(
                  color: isExpired ? Colors.white38 : const Color(0xFF070D1E),
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.2,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
